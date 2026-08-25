/// Turns a raw web-frequency list into a teachable vocabulary list.
///
///   dart run tool/filter_wordlist.dart tool/google-10000-english-no-swears.txt \
///       --out tool/words_vocabulary.txt
///
/// Lists like `google-10000-english` rank words by how often they appear on the
/// web, which is not the same as being worth teaching. They are full of
/// abbreviations, file extensions, brand names and inflected forms whose base
/// word is already in the list. Generating five sentences and three definitions
/// for "aol" or for both "record" and "records" wastes effort and makes the app
/// worse — the learner gets drilled on noise, and the scheduler treats the same
/// word as two.
///
/// Rejected words are written to `<out>.rejected.txt` with the reason, so the
/// filter can be argued with rather than trusted blindly.
library;

import 'dart:convert';
import 'dart:io';

/// Words shorter than this are initials, units or file extensions.
const int minLength = 3;

/// Abbreviations, units and web/file jargon. Frequent on the web, useless as
/// vocabulary.
const Set<String> _jargon = {
  'macromedia', 'mastercard', 'kijiji', 'cfr', 'vii', 'nano',
  'por', 'mem', 'tribune',
  'univ', 'tft', 'jvc', 'butts',
  'bizrate', 'gamespot', 'wordpress', 'sox',
  'sys', 'solaris', 'icq',
  'nav', 'verizon', 'lambda', 'lil', 'thomson',
  'nascar',
  'pos', 'utils', 'phys', 'dialog', 'vic',
  'atm', 'lang',
  'peeing',
  'cbs', 'nbc', 'spec', 'midi', 'realty',
  'proc', 'olympus', 'lotus',
  'kde', 'qt',
  'kodak', 'approx', 'filename',
  'vid', 'fda', 'hdtv', 'expansys',
  'std',
  'aaa', 'macintosh', 'sucking',
  'gen', 'espn', 'marriott',
  'mozilla', 'oclc', 'plc', 'msg',
  'dos', 'combo',
  'oem', 'lycos', 'zdnet', 'cnet', 'pcworld',
  'chi', 'rfc', 'ins',
  'gbp', 'jelsoft', 'photoshop', 'housewares', 'slideshow',
  'lite', 'ghz', 'skype', 'gamecube', 'eng',
  'tcp', 'dir', 'flickr', 'val', 'medicare',
  'goto', 'iframe',
  'ncaa', 'phd', 'pentium', 'aka', 'blogging',
  'xhtml', 'dhtml',
  'dealtime', 'temp', 'intro', 'tramadol', 'ent', 'vicodin', 'phentermine',
  'mrs', 'inkjet', 'warner',
  'struct', 'titans', 'herein',
  'rev', 'nyc',
  'sur', 'packard', 'hewlett',
  'cal', 'rpm', 'tvs', 'cached', 'pee',
  'compaq', 'showtimes', 'emachines', 'netgear',
  'hrs', 'chevrolet', 'ford', 'audi', 'yen',
  'usc', 'trembl', 'blvd', 'amd', 'ave', 'ext',
  'aud', 'cad', 'spanking', 'fetish',
  'telecom', 'nikon', 'canon', 'panasonic',
  'nec', 'foto', 'vista', 'winxp',
  'config', 'urw', 'wishlist', 'asin',
  'trans', 'ver', 'nvidia',
  'mod', 'bmw', 'twiki', 'rep', 'ceo', 'cto', 'cfo',
  'tion', 'citysearch', 'nsw', 'pci', 'guestbook', 'ttf', 'scsi', 'ide',
  'hist', 'inter', 'vbulletin', 'phpbb',
  'def', 'org', 'ethernet', 'postposted', 'testimonials', 'cialis', 'epa', 'viagra', 'xanax',
  'mph', 'modem', 'kbps', 'mbps', 'pixels', 'dpi',
  'abc', 'livecam', 'biz', 'gcc', 'exp', 'lbs', 'lol',
  'semi', 'cpanel', 'anytime',
  'uniprotkb', 'pmid', 'medline', 'pubmed', 'ncbi', 'sci', 'med',
  'ing', 'para', 'pcs', 'bio', 'sms', 'mms',
  'qty', 'templates', 'template', 'router', 'metadata', 'thumbnail',
  'voip', 'blogger', 'podcast', 'wiki', 'url', 'seo', 'cms', 'crm',
  'wikipedia', 'res', 'que', 'header', 'footer', 'registry', 'admin',
  'const', 'dont', 'wont', 'cant', 'isnt', 'didnt', 'doesnt', 'arent',
  'werent', 'wasnt', 'couldnt', 'wouldnt', 'shouldnt', 'havent',
  'hasnt', 'hadnt', 'youre', 'theyre', 'thats', 'whats', 'lets',
  'char', 'int', 'bool', 'str', 'var', 'func', 'init', 'args',
  'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'sept', 'oct', 'nov',
  'dec', 'mon', 'tue', 'tues', 'wed', 'thu', 'thur', 'thurs', 'fri', 'sat',
  'sun', 'inc', 'ltd', 'corp', 'dept', 'etc', 'vs', 'via', 'per',
  'urls', 'http', 'https', 'www', 'html', 'htm', 'xml', 'php', 'asp',
  'aspx', 'cgi', 'css', 'sql', 'ftp', 'pdf', 'jpg', 'jpeg', 'gif', 'png',
  'mpeg', 'avi', 'exe', 'zip', 'rss', 'faq', 'faqs', 'api', 'apis',
  'cdn', 'dns', 'ssl', 'gnu', 'ascii', 'utf', 'iso', 'isbn', 'issn',
  'perl', 'lib', 'utc', 'cam', 'gmt', 'src', 'img', 'nbsp', 'href',
  'weblog', 'mysql', 'pdt', 'pst', 'edt', 'cst', 'est', 'javascript', 'java',
  'epinions', 'psp', 'nfl', 'nba', 'mlb', 'nhl', 'cnn', 'bbc', 'nasa', 'fbi',
  'misc', 'holdem', 'vat',
  'cia', 'nato', 'unesco', 'ieee', 'ibid', 'pty', 'llc', 'gmbh',
  'python', 'ruby', 'ajax', 'jsp', 'servlet', 'oracle', 'sybase', 'postgres',
  'freeware', 'shareware', 'spyware', 'adware', 'malware', 'firewall',
  'broadband', 'dsl', 'isp', 'lan', 'wan', 'usb', 'cpu', 'ram', 'rom',
  'aol', 'msn', 'ebay', 'paypal', 'amazon', 'google', 'yahoo', 'microsoft',
  'apple', 'ibm', 'intel', 'nokia', 'sony', 'toshiba', 'dell', 'hp', 'cisco',
  'adobe', 'netscape', 'firefox', 'linux', 'unix', 'windows',
  'hosting', 'downloads', 'download', 'upload', 'uploads', 'login', 'logout',
  'username', 'usernames', 'personals', 'modules', 'module', 'plugin',
  'plugins', 'blog', 'blogs', 'webmaster', 'sitemap', 'homepage',
  'ecommerce', 'online', 'offline', 'website', 'websites', 'webpage',
  'pic', 'pics', 'thumbnails', 'screenshot',
};

/// Common given names, surnames and place names that appear in web-frequency
/// lists. Not exhaustive — proper nouns cannot be detected reliably without a
/// reference dictionary, so the rejected file is worth reading.
const Set<String> _properNouns = {
  'lauren', 'ashley', 'cambodia', 'victorian',
  'colin', 'samoa',
  'estonia', 'katie', 'namibia', 'christina', 'latvia', 'lithuania',
  'bahamas', 'powell', 'hampton', 'bobby', 'salvador', 'ali', 'monroe', 'tanzania',
  'stanford', 'soviet',
  'solomon', 'josh', 'rochester',
  'tommy', 'springfield', 'oliver', 'congo', 'glen', 'botswana', 'newcastle', 'honolulu', 'dominican', 'chad',
  'newport', 'bangladesh', 'iceland',
  'blair', 'victor', 'mario', 'brunswick', 'hudson',
  'queensland', 'raleigh',
  'newton',
  'pete', 'penn', 'lopez',
  'harrison', 'harvey', 'wallace',
  'luxembourg', 'joel', 'perry', 'salem', 'luke',
  'arabic', 'kingston', 'ted',
  'stanley', 'murphy',
  'lynn',
  'todd', 'doug', 'montgomery', 'louisville', 'monica',
  'reuters', 'bloomberg',
  'palestinian',
  'mitsubishi', 'delhi', 'nepal', 'zimbabwe', 'juan',
  'brad', 'fisher',
  'norfolk',
  'norton', 'lanka', 'berkeley',
  'arabia', 'indianapolis', 'yorkshire',
  'albany', 'pierre', 'oakland',
  'britney', 'katrina', 'portuguese', 'halloween',
  'durham', 'neil', 'robinson', 'jacksonville', 'israeli', 'olympic',
  'murray',
  'jefferson', 'lincolnshire',
  'mercedes',
  'harvard', 'nike', 'yale', 'princeton', 'adidas', 'reebok',
  'minneapolis', 'omaha', 'tulsa',
  'eminem', 'madonna', 'elvis', 'beatles',
  'rica', 'costa',
  'walter', 'duncan', 'stuart',
  'rio',
  'lebanon', 'kennedy', 'cooper', 'islamic',
  'broadway', 'hollywood',
  'charlie', 'francis', 'warren',
  'saudi', 'kate',
  'cyprus', 'marc', 'malta',
  'thai', 'fred', 'afghanistan',
  'rick', 'donald', 'trevor',
  'iraqi', 'amsterdam', 'iranian', 'afghan',
  'ross', 'sri',
  'gordon', 'rico', 'phil', 'simpson', 'kerry', 'dicke',
  'kent',
  'mexican', 'korean', 'thompson', 'brazilian', 'greek', 'turkish',
  'rhode', 'greg', 'ron', 'clinton', 'cincinnati', 'richmond', 'sierra', 'scottish', 'irish', 'welsh',
  'tiffany',
  'matthew', 'anthony', 'franklin', 'morgan', 'columbus', 'andy', 'christopher',
  'madison', 'jon', 'douglas', 'ken', 'jay', 'valentine', 'apache',
  'epson', 'nintendo', 'hilton', 'debian', 'ubuntu', 'novell',
  'birmingham', 'anne', 'alex', 'marshall', 'hamilton', 'siemens',
  'honda', 'toyota', 'nokia', 'yamaha', 'nissan', 'mazda',
  'dutch', 'nick', 'danish', 'swedish', 'norwegian', 'finnish', 'polish',
  'puerto', 'latina', 'latino', 'hispanic', 'anglo', 'euro',
  'simon', 'pittsburgh', 'cleveland', 'detroit', 'baltimore', 'milwaukee',
  // people
  'john', 'david', 'michael', 'james', 'robert', 'william', 'richard',
  'thomas', 'charles', 'joseph', 'daniel', 'paul', 'mark', 'george', 'peter',
  'steven', 'andrew', 'kenneth', 'joshua', 'kevin', 'brian', 'eric', 'martin',
  'jason', 'jeffrey', 'ryan', 'gary', 'nicholas', 'stephen', 'jonathan',
  'larry', 'justin', 'scott', 'brandon', 'frank', 'benjamin', 'gregory',
  'samuel', 'raymond', 'patrick', 'alexander', 'jack', 'dennis', 'jerry',
  'mary', 'patricia', 'linda', 'barbara', 'elizabeth', 'jennifer', 'maria',
  'susan', 'margaret', 'dorothy', 'lisa', 'nancy', 'karen', 'betty', 'helen',
  'sandra', 'donna', 'carol', 'ruth', 'sharon', 'michelle', 'laura', 'sarah',
  'kimberly', 'deborah', 'jessica', 'shirley', 'cynthia', 'angela', 'melissa',
  'brenda', 'amy', 'anna', 'rebecca', 'virginia', 'kathleen', 'taylor',
  'victoria', 'smith', 'johnson', 'williams', 'jones', 'brown', 'miller',
  'wilson', 'moore', 'anderson', 'jackson', 'harris', 'clark', 'lewis',
  'walker', 'hall', 'young', 'king', 'wright', 'hill', 'green', 'adams',
  'baker', 'nelson', 'carter', 'mitchell', 'roberts', 'turner', 'phillips',
  'campbell', 'parker', 'evans', 'edwards', 'collins', 'stewart', 'morris',
  // places
  'america', 'american', 'africa', 'asia', 'europe', 'australia', 'canada',
  'england', 'britain', 'british', 'ireland', 'scotland', 'wales', 'france',
  'french', 'germany', 'german', 'spain', 'spanish', 'italy', 'italian',
  'portugal', 'holland', 'belgium', 'sweden', 'norway', 'denmark', 'finland',
  'poland', 'russia', 'russian', 'china', 'chinese', 'japan', 'japanese',
  'korea', 'india', 'indian', 'pakistan', 'israel', 'egypt', 'turkey',
  'greece', 'mexico', 'brazil', 'argentina', 'chile', 'peru', 'cuba',
  'london', 'paris', 'berlin', 'madrid', 'rome', 'moscow', 'tokyo', 'beijing',
  'sydney', 'toronto', 'chicago', 'boston', 'seattle', 'denver', 'atlanta',
  'dallas', 'houston', 'phoenix', 'miami', 'vegas', 'york', 'jersey',
  'california', 'texas', 'florida', 'ohio', 'michigan', 'georgia',
  'carolina', 'indiana', 'missouri', 'tennessee', 'wisconsin', 'minnesota',
  'colorado', 'alabama', 'louisiana', 'kentucky', 'oregon', 'oklahoma',
  'connecticut', 'iowa', 'mississippi', 'arkansas', 'kansas', 'utah',
  'nevada', 'nebraska', 'idaho', 'hawaii', 'alaska', 'maine', 'montana',
  'delaware', 'wyoming', 'vermont', 'arizona', 'illinois', 'pennsylvania',
  'massachusetts', 'washington', 'oxford', 'cambridge', 'liverpool', 'jordan',
  'tony', 'thailand', 'christian', 'jesus', 'islam', 'muslim', 'jewish',
  'portland', 'sam', 'allen', 'switzerland', 'czech', 'howard', 'austria',
  'adam', 'antonio', 'orleans', 'swiss', 'caribbean', 'pacific', 'atlantic',
  'arab', 'lincoln', 'guinea', 'vancouver', 'catholic', 'protestant',
  'jose', 'jane', 'kim', 'charlotte',
  'memphis', 'nashville', 'orlando', 'tampa', 'sacramento',
  'brooklyn', 'harlem', 'queens', 'bronx', 'manhattan',
  'hindu', 'buddhist', 'baptist', 'methodist', 'anglican', 'roman',
  'montreal', 'ottawa', 'calgary', 'quebec', 'alberta', 'manitoba',
  'melbourne', 'brisbane', 'perth', 'adelaide', 'auckland', 'wellington',
  'mediterranean', 'arctic', 'antarctic', 'himalaya', 'amazon', 'sahara',
  'danny', 'nathan', 'zachary', 'kyle', 'noah', 'ethan', 'logan', 'lucas',
  'mason', 'jacob', 'dylan', 'caleb', 'isaac', 'owen', 'gavin', 'ian',
  'emma', 'olivia', 'sophia', 'isabella', 'mia', 'abigail', 'emily', 'chloe',
  'grace', 'lily', 'hannah', 'ella', 'aubrey', 'zoe', 'natalie', 'leah',
  'audrey', 'claire', 'sadie', 'eva', 'nora', 'ruby', 'iris', 'june',
  'hungary', 'romania', 'bulgaria', 'croatia', 'serbia', 'ukraine', 'vietnam',
  'indonesia', 'malaysia', 'singapore', 'philippines', 'taiwan', 'nigeria',
  'kenya', 'morocco', 'algeria', 'tunisia', 'ecuador', 'bolivia', 'uruguay',
  'paraguay', 'venezuela', 'colombia', 'panama', 'jamaica', 'bermuda',
  'edinburgh', 'glasgow', 'dublin', 'belfast', 'manchester', 'bristol',
  'leeds', 'sheffield', 'nottingham', 'brighton', 'vienna', 'prague',
  'budapest', 'warsaw', 'lisbon', 'athens', 'geneva', 'zurich', 'munich',
  'hamburg', 'frankfurt', 'stuttgart', 'milan', 'venice', 'florence',
  'naples', 'barcelona', 'valencia', 'seville', 'lyon', 'marseille',
  'andrea', 'julie', 'diane', 'christine', 'catherine', 'janet', 'marie',
  'frances', 'joan', 'evelyn', 'alice', 'judy', 'julia', 'joyce', 'louise',
  'gloria', 'jean', 'teresa', 'doris', 'gladys', 'rachel', 'marilyn',
  'wayne', 'roy', 'ralph', 'eugene', 'louis', 'philip', 'johnny',
  'craig', 'carl', 'harold', 'arthur', 'lawrence', 'jesse', 'bruce', 'billy',
  'bryan', 'joe', 'albert', 'willie', 'gerald', 'roger', 'keith', 'jeremy',
  'terry', 'sean', 'aaron', 'randy', 'barry', 'alan', 'russell', 'shawn',
  'clarence', 'norman', 'marvin', 'vincent', 'glenn', 'travis',
};

/// Words that end in "s" but are not the plural of the word left when you
/// strip it — either they have no singular at all, or the "-s" form carries a
/// different meaning worth teaching on its own.
///
/// Without this, the plural rule quietly deletes real vocabulary: "news" is
/// not the plural of "new", "arms" is not just more than one arm, and
/// "glasses" is not two pieces of glass.
const Set<String> _notReallyPlural = {
  'news', 'means', 'lens', 'series', 'species', 'clothes', 'glasses',
  'sunglasses', 'jeans', 'shorts', 'trousers', 'pants', 'scissors', 'stairs',
  'goods', 'odds', 'thanks', 'arms', 'customs', 'savings', 'earnings',
  'belongings', 'surroundings', 'premises', 'contents', 'regards', 'spirits',
  'headquarters', 'outskirts', 'damages', 'forces', 'minutes', 'works',
  'looks', 'authorities', 'media', 'physics', 'politics', 'economics',
  'mathematics', 'statistics', 'ethics', 'graphics', 'dynamics', 'logistics',
  'olympics', 'athletics', 'gymnastics', 'electronics',
  // adverbs and prepositions that merely happen to end in "s"
  'always', 'perhaps', 'sometimes', 'besides', 'towards', 'upwards',
  'downwards', 'indoors', 'outdoors', 'afterwards', 'otherwise', 'nevertheless',
};


/// German fragments. This list was scraped from web traffic and a number of
/// German function words rode along with it.
///
/// Words that are also English are deliberately absent: "die", "was", "man"
/// and "den" all appear here in German, but dropping them would delete real
/// English vocabulary.
const Set<String> _germanNoise = {
  'travesti',
  'titten',
  'zus',
  'deutsch', 'nutten',
  'der', 'das', 'und', 'zum', 'zur', 'mit', 'von', 'ist', 'eine', 'einen',
  'einem', 'einer', 'verzeichnis', 'sich', 'auch', 'werden', 'nicht', 'aber',
  'oder', 'wenn', 'durch', 'nach', 'bei', 'aus', 'dem', 'des', 'als', 'wie',
  'nur', 'noch', 'schon', 'hier', 'sind', 'haben', 'wird', 'kann', 'mehr',
  'sehr', 'alle', 'jetzt', 'dass', 'wir', 'sie', 'ich', 'ihre', 'ihren',
  'diese', 'dieser', 'kein', 'keine', 'wurde', 'wurden', 'unter', 'zwischen',
  'gegen', 'ohne', 'seit', 'immer', 'wieder', 'viele', 'etwa', 'sowie',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: filter_wordlist.dart <input.txt> [--out <file>]');
    exit(64);
  }

  final inputPath = args.first;
  final outPath = _flag(args, 'out') ?? 'tool/words_vocabulary.txt';

  final words = _read(inputPath);
  final all = words.toSet();

  final kept = <String>[];
  final rejected = <(String, String)>[];

  for (final word in words) {
    final reason = _rejectionReason(word, all);
    if (reason == null) {
      kept.add(word);
    } else {
      rejected.add((word, reason));
    }
  }

  File(outPath).writeAsStringSync(
    '# Vocabulary list, filtered from $inputPath by tool/filter_wordlist.dart\n'
    '# ${kept.length} words kept, ${rejected.length} rejected.\n'
    '# Order is preserved, so line position is still the frequency rank.\n'
    '${kept.join('\n')}\n',
  );

  final rejectedPath = '$outPath.rejected.txt';
  File(rejectedPath).writeAsStringSync(
    '# Rejected by tool/filter_wordlist.dart — read this before trusting it.\n'
    '${rejected.map((r) => '${r.$1}\t${r.$2}').join('\n')}\n',
  );

  // The plural reasons name the base word, so group them for the summary and
  // leave the detail in the rejected file.
  final counts = <String, int>{};
  for (final (_, reason) in rejected) {
    final category =
        reason.startsWith('plural of') ? 'plural of a word already listed' : reason;
    counts[category] = (counts[category] ?? 0) + 1;
  }

  stdout.writeln('Read    : ${words.length} words from $inputPath');
  stdout.writeln('Kept    : ${kept.length}  -> $outPath');
  stdout.writeln('Rejected: ${rejected.length}  -> $rejectedPath');
  for (final entry in counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value))) {
    stdout.writeln('  ${entry.value.toString().padLeft(5)}  ${entry.key}');
  }
}

/// Why [word] is not worth teaching, or null to keep it.
String? _rejectionReason(String word, Set<String> all) {
  if (word.length < minLength) return 'shorter than $minLength letters';
  if (!RegExp(r'^[a-z]+$').hasMatch(word)) return 'not plain letters';
  if (_jargon.contains(word)) return 'abbreviation or web jargon';
  if (_properNouns.contains(word)) return 'proper noun';
  if (_germanNoise.contains(word)) return 'German, not English';

  final base = _singularOf(word, all);
  if (base != null && all.contains(base)) {
    return 'plural of "$base", which is already in the list';
  }
  return null;
}

/// The singular of [word], if it looks like a regular plural.
///
/// Deliberately conservative: it only strips an ending when the result is
/// itself in the list, so "boss" and "gas" survive but "records" does not.
String? _singularOf(String word, Set<String> all) {
  if (_notReallyPlural.contains(word)) return null;
  if (word.endsWith('ies') && word.length > 4) {
    final asY = '${word.substring(0, word.length - 3)}y';
    if (all.contains(asY)) return asY;
    // "cookies" is not "cooky" — some "-ies" words simply end in "-ie".
    return word.substring(0, word.length - 1);
  }
  if (word.endsWith('es') && word.length > 3) {
    // "boxes" drops the whole "es", "conferences" only the "s". Try the
    // longer stem first: the caller keeps a stem only if the list has it.
    final withoutS = word.substring(0, word.length - 1);
    if (all.contains(withoutS)) return withoutS;
    return word.substring(0, word.length - 2);
  }
  if (word.endsWith('s') && !word.endsWith('ss') && word.length > 3) {
    return word.substring(0, word.length - 1);
  }
  return null;
}

List<String> _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Not found: $path');
    exit(66);
  }
  return [
    for (final line in const LineSplitter().convert(file.readAsStringSync()))
      if (line.trim().isNotEmpty && !line.startsWith('#')) line.trim(),
  ];
}

String? _flag(List<String> args, String name) {
  final index = args.indexOf('--$name');
  return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
}
