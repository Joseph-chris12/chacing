/// Daftar transaksi dikelompokkan per hari, lengkap dengan subtotal harian.
///
/// Geser untuk hapus, ketuk untuk ubah. Penghapusan selalu bisa dibatalkan
/// lewat snackbar: transaksi hanya ditandai terhapus, tidak dibuang, jadi
/// membatalkannya cukup memulihkan baris yang sama.
library;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:chacing/data/database.dart';
import 'package:chacing/domain/daily_group.dart';
import 'package:chacing/ui/category_icons.dart';
import 'package:chacing/ui/format.dart';

class TransactionList extends StatelessWidget {
  const TransactionList({
    super.key,
    required this.transactions,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
    this.header,
  });

  final List<Transaction> transactions;
  final List<Category> categories;
  final void Function(Transaction) onEdit;
  final void Function(Transaction) onDelete;

  /// Ditempel sebagai baris pertama supaya ikut menggulir bersama daftar.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final groups = groupByDay<Transaction>(
      transactions,
      dateOf: (t) => t.occurredAt,
      // `ownShare`, bukan `total`. Uang talangan orang lain bukan
      // pengeluaranmu, dan subtotal harian harus mencerminkan itu.
      amountOf: (t) => t.ownShare,
    );

    final categoryById = {for (final c in categories) c.id: c};

    return CustomScrollView(
      slivers: [
        if (header != null)
          SliverToBoxAdapter(child: header),
        if (groups.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else
          for (final group in groups) ...[
            SliverToBoxAdapter(child: _DayHeader(group: group)),
            SliverList.builder(
              itemCount: group.entries.length,
              itemBuilder: (context, index) {
                final transaction = group.entries[index];
                return _TransactionTile(
                  transaction: transaction,
                  category: categoryById[transaction.categoryId],
                  onEdit: () => onEdit(transaction),
                  onDelete: () => onDelete(transaction),
                );
              },
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final DailyGroup<Transaction> group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formatRelativeDate(group.date),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            formatRupiah(group.subtotal),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Transaction transaction;
  final Category? category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Transaksi yang ditalangi bersama menampilkan dua angka, karena
    // "keluar dari dompet 300rb tapi porsimu 75rb" adalah dua fakta
    // berbeda yang sama-sama perlu dilihat.
    final isSplit = transaction.ownShare != transaction.total;

    return Slidable(
      key: ValueKey(transaction.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        dismissible: DismissiblePane(onDismissed: onDelete),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
            icon: Icons.delete_outline,
            label: 'Hapus',
          ),
        ],
      ),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          child: Icon(categoryIcon(category?.icon), size: 20),
        ),
        title: Text(
          transaction.merchant,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(category?.name ?? 'Tanpa kategori'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatRupiah(transaction.ownShare),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (isSplit)
              Text(
                'dari ${formatRupiah(transaction.total)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text('Belum ada catatan minggu ini', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Ketuk tombol Catat di bawah untuk\nmenambah pengeluaran pertama.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
