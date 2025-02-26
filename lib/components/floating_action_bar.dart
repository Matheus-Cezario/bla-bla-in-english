import 'package:flutter/material.dart';

class FloatingActionBar extends StatelessWidget {
  const FloatingActionBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 8,
        color: Theme.of(context).colorScheme.primary,
        child: SizedBox(
          height: 60,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton.filled(
                onPressed: () {},
                icon: Icon(
                  Icons.close,
                ),
              ),
              IconButton.filled(
                onPressed: () {},
                icon: Icon(
                  Icons.square_outlined,
                ),
              ),
              IconButton.filled(
                onPressed: () {},
                icon: Icon(
                  Icons.check_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
