// import 'package:bla_bla_in_english/providers/cards_state_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// class FloatingActionBar extends StatelessWidget {
//   const FloatingActionBar({
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final cartsState = Provider.of<CardsStateProvider>(context);
//     final textTheme = Theme.of(context).textTheme;

//     final colorScheme = Theme.of(context).colorScheme;

//     return Padding(
//       padding: const EdgeInsets.all(15.0),
//       child: Card(
//         // elevation: 8,
//         color: colorScheme.primary,
//         child: SizedBox(
//           height: 60,
//           width: double.infinity, //double.infinity,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               if (cartsState.isUnFliped)
//                 TextButton(
//                     onPressed: cartsState.toNextStep,
//                     child: Text(
//                       'Girar a carta!',
//                       style: textTheme.bodyMedium,
//                     ))
//               else if (cartsState.isFliped)
//                 TextButton(
//                   onPressed: cartsState.toNextStep,
//                   child: Text(
//                     'Revelar a carta!',
//                     style: textTheme.bodyMedium,
//                   ),
//                 )
//               else ...[
//                 IconButton(
//                   onPressed: cartsState.toNextStep,
//                   icon: Icon(
//                     Icons.close,
//                   ),
//                 ),
//                 IconButton(
//                   onPressed: cartsState.toNextStep,
//                   icon: Icon(
//                     Icons.square_outlined,
//                   ),
//                 ),
//                 IconButton(
//                   onPressed: cartsState.toNextStep,
//                   icon: Icon(
//                     Icons.check_rounded,
//                   ),
//                 ),
//               ]
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
