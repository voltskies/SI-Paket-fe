import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';

class AdminPaketScreen extends StatefulWidget {
  const AdminPaketScreen({super.key});

  @override
  State<AdminPaketScreen> createState() => _AdminPaketScreenState();
}

class _AdminPaketScreenState extends State<AdminPaketScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _daftarPaket = [];
  String _selectedStatus = ''; // '' = Semua (tanpa query ?status)
  String? _selectedResi;
  String _selectedTransit = 'DC Surabaya';

  @override
  void initState() {
    super.initState();
    _fetchPaket();
  }

  Future<void> _fetchPaket() async {
    setState(() => _isLoading = true);
    try {
      // Memanggil GET /api/gudang/paket atau GET /api/gudang/paket?status=<status_terkini>
      final raw = await ApiService.getGudangPaket(
        status: _selectedStatus.isEmpty ? null : _selectedStatus,
      );
      if (!mounted) return;
      setState(() {
        _daftarPaket = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchPaket,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Semua Daftar Paket',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              IconButton(
                onPressed: _fetchPaket,
                icon: const Icon(Icons.refresh, color: AppColors.navyPrimary),
              ),
            ],
          ),
          Text(
            'Total ${_daftarPaket.length} paket di database',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Filter Status -> mengirim ?status=status_terkini ke /api/paket/saya
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua', ''),
                const SizedBox(width: 8),
                _buildFilterChip('Menunggu', 'Menunggu Penjemputan'),
                const SizedBox(width: 8),
                _buildFilterChip('Perjalanan', 'Dalam Perjalanan'),
                const SizedBox(width: 8),
                _buildFilterChip('Selesai', 'Selesai'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.navyPrimary),
              ),
            )
          else if (_daftarPaket.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'Belum ada data paket pada filter ini.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ..._daftarPaket.map((paket) => _buildPaketCard(paket)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String statusValue) {
    final selected = _selectedStatus == statusValue;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedStatus = statusValue);
        _fetchPaket();
      },
    );
  }

  Widget _buildPaketCard(Map<String, dynamic> paket) {
    final resi = (paket['noResi'] ?? paket['no_resi'] ?? '-').toString();
    final penerima = (paket['namaPenerima'] ?? paket['nama_penerima'] ?? '-')
        .toString();
    final tujuan = (paket['alamatTujuan'] ?? paket['alamat_tujuan'] ?? '-')
        .toString();
    final jenis = (paket['jenisPaket'] ?? paket['jenis_paket'] ?? 'Reguler')
        .toString();
    final status =
        (paket['statusTerkini'] ??
                paket['status_terkini'] ??
                'Menunggu Penjemputan')
            .toString();

    final isPerjalanan =
        status.toLowerCase().contains('perjalanan') ||
        status.toLowerCase().contains('antar');

    final isSelected = _selectedResi == resi;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedResi = resi);
        _showUpdatePaketSheet(paket);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.navyPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: AppColors.navyPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  resi,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              penerima,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tujuan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  jenis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPerjalanan ? AppColors.badgeBlueBg : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isPerjalanan
                      ? AppColors.badgeBlueText
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Ketuk untuk update paket',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyPrimary,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppColors.navyPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUpdatePaketSheet(Map<String, dynamic> paket) async {
    final resi = (paket['noResi'] ?? paket['no_resi'] ?? '-').toString();
    final penerima = (paket['namaPenerima'] ?? paket['nama_penerima'] ?? '-')
        .toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Paket',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$resi - $penerima',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tambah titik riwayat',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: ['DC Cakung', 'DC Semarang', 'DC Surabaya']
                        .map(
                          (dc) => ChoiceChip(
                            label: Text(dc),
                            selected: _selectedTransit == dc,
                            onSelected: (_) {
                              setSheetState(() => _selectedTransit = dc);
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              setSheetState(() => _isSubmitting = true);
                              setState(() => _isSubmitting = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(sheetContext);
                              try {
                                await ApiService.tambahTransit(
                                  noResi: resi,
                                  lokasiUpdate: _selectedTransit,
                                );
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Titik transit $_selectedTransit berhasil ditambahkan!',
                                    ),
                                    backgroundColor: AppColors.navyPrimary,
                                  ),
                                );
                                navigator.pop();
                                await _fetchPaket();
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isSubmitting = false);
                                }
                                if (sheetContext.mounted) {
                                  setSheetState(() => _isSubmitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text(
                        'Simpan Titik Transit',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
