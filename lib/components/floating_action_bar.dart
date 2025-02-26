import 'package:bla_bla_in_english/providers/carts_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FloatingActionBar extends StatelessWidget {
  const FloatingActionBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cartsState = Provider.of<CartsStateProvider>(context);

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
              if (cartsState.isUnFliped)
                TextButton(
                    onPressed: cartsState.toNextStep,
                    child: Text(
                      'Girar a carta!',
                      style: TextStyle(color: Colors.black),
                    ))
              else if (cartsState.isFliped)
                TextButton(
                  onPressed: cartsState.toNextStep,
                  child: Text(
                    'Revelar a carta!',
                    style: TextStyle(color: Colors.black),
                  ),
                )
              else ...[
                IconButton.filled(
                  onPressed: cartsState.toNextStep,
                  icon: Icon(
                    Icons.close,
                  ),
                ),
                IconButton.filled(
                  onPressed: cartsState.toNextStep,
                  icon: Icon(
                    Icons.square_outlined,
                  ),
                ),
                IconButton.filled(
                  onPressed: cartsState.toNextStep,
                  icon: Icon(
                    Icons.check_rounded,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
