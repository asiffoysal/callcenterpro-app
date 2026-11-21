import 'package:flutter/material.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';

class KeypadScreen extends StatefulWidget {
  const KeypadScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<KeypadScreen> {
  String _n = '';
  static const _keys = [
    ['1', ''], ['2', 'ABC'], ['3', 'DEF'],
    ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
    ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
    ['*', ''], ['0', '+'], ['#', ''],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 24),
      Expanded(
        child: Center(
          child: Text(_n.isEmpty ? 'Enter a number' : _n,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500,
                  color: _n.isEmpty ? Theme.of(context).colorScheme.outline : null)),
        ),
      ),
      GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        childAspectRatio: 1.4,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        children: _keys.map((k) => InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () => setState(() => _n += k[0]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(k[0], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
            if (k[1].isNotEmpty) Text(k[1], style: const TextStyle(fontSize: 10, letterSpacing: 2)),
          ]),
        )).toList(),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FloatingActionButton(
            heroTag: 'call',
            backgroundColor: BrandTheme.available,
            onPressed: widget.session.can('outbound') ? () {} : null,
            child: const Icon(Icons.call, color: Colors.white),
          ),
          const SizedBox(width: 24),
          IconButton(
            icon: const Icon(Icons.backspace_outlined),
            onPressed: _n.isEmpty ? null : () => setState(() => _n = _n.substring(0, _n.length - 1)),
          ),
        ]),
      ),
    ]);
  }
}
