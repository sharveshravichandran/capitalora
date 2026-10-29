import 'package:flutter/material.dart';

import 'data.dart';

/// Asset image that shows a progress bar until it has loaded, with a
/// colourful gradient fallback if the file is missing.
class AppImage extends StatelessWidget {
  final String asset;
  final double height;
  final Widget? overlay;
  const AppImage(this.asset, {super.key, this.height = 180, this.overlay});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, sync) {
              if (sync || frame != null) return child;
              return const Center(
                  child: SizedBox(width: 140, child: LinearProgressIndicator()));
            },
            errorBuilder: (context, error, stack) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Color(0xFF00BFA5),
                  Color(0xFF7C4DFF),
                  Color(0xFFFF4081),
                ]),
              ),
            ),
          ),
          if (overlay != null) ...[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xAA000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(alignment: Alignment.bottomLeft, child: overlay),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Full-screen loader used while auth / role are being resolved.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('My Wealth',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            LinearProgressIndicator(
                minHeight: 6, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 8),
            const Text('Loading…'),
          ]),
        ),
      ),
    );
  }
}

/// Thin progress bar (and error text) shown under the app bar.
class LoadingStrip extends StatelessWidget {
  final bool loading;
  final String? error;
  const LoadingStrip({super.key, required this.loading, this.error});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (loading)
        const LinearProgressIndicator(minHeight: 4)
      else
        const SizedBox(height: 4),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
    ]);
  }
}

class YearBar extends StatelessWidget {
  final WealthStore store;
  const YearBar(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(
          onPressed: () => store.setYear(store.year - 1),
          icon: const Icon(Icons.chevron_left)),
      Text('${store.year}', style: Theme.of(context).textTheme.titleLarge),
      IconButton(
          onPressed: () => store.setYear(store.year + 1),
          icon: const Icon(Icons.chevron_right)),
    ]);
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const StatTile(this.label, this.value, this.color, this.icon, {super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withAlpha(40),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(money.format(value),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $what?'),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete')),
      ],
    ),
  );
  return ok ?? false;
}
