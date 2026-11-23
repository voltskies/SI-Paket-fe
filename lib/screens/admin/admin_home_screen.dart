import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../role_selection_screen.dart';
import 'admin_paket_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedNavIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _daftarPaket = [];
  List<Map<String, dynamic>> _daftarKurir = [];

  final _idPelangganController = TextEditingController(text: '1');
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _beratController = TextEditingController(text: '2.4');
  bool _isExpress = false;

  String? _selectedResiForAction;
  int? _selectedKurirId;
  String _searchQuery = '';
  String _adminNama = 'Admin Pos';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final paketRaw = await ApiService.getGudangPaket();
      final kurirRaw = await ApiService.getDaftarKurir();
      final nama = await ApiService.getNama();

      final paketList = paketRaw
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final kurirList = kurirRaw
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _adminNama = nama ?? 'Admin Pos';
        _daftarPaket = paketList;
        _daftarKurir = kurirList;

        if (_daftarPaket.isNotEmpty) {
          final validResi = _daftarPaket.any(
            (p) => p['noResi']?.toString() == _selectedResiForAction,
          );
          if (!validResi) {
            _selectedResiForAction = _daftarPaket.first['noResi']?.toString();
          }
        } else {
          _selectedResiForAction = null;
        }

        if (_daftarKurir.isNotEmpty) {
          final validKurir = _daftarKurir.any(
            (k) =>
                int.tryParse(k['idPengguna']?.toString() ?? '') ==
                _selectedKurirId,
          );
          if (!validKurir) {
            _selectedKurirId = int.tryParse(
              _daftarKurir.first['idPengguna']?.toString() ?? '',
            );
          }
        } else {
          _selectedKurirId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _beratVal =>
      double.tryParse(_beratController.text.replaceAll(',', '.')) ?? 1.0;

  int get _estimasiOngkir => _beratVal.ceil() * (_isExpress ? 18000 : 10000);

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.navyPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _simpanPaketBaru() async {
    final idPelanggan = int.tryParse(_idPelangganController.text.trim());
    if (idPelanggan == null ||
        _namaController.text.trim().isEmpty ||
        _alamatController.text.trim().isEmpty) {
      _showSnack(
        'Isi ID pelanggan, nama penerima, dan alamat tujuan dulu!',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService.buatPaketGudang(
        idPengguna: idPelanggan,
        namaPenerima: _namaController.text.trim(),
        alamatAsal: 'DC Surabaya',
        alamatTujuan: _alamatController.text.trim(),
        beratKg: _beratVal,
        jenisPaket: _isExpress ? 'Express' : 'Reguler',
      );

      _namaController.clear();
      _alamatController.clear();
      _showSnack('Paket baru & resi berhasil disimpan ke database!');
      await _loadData();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _tugaskanKurir() async {
    if (_selectedResiForAction == null || _selectedKurirId == null) {
      _showSnack('Pilih resi dan kurir terlebih dahulu.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService.assignKurir(
        noResi: _selectedResiForAction!,
        idKurir: _selectedKurirId!,
      );
      _showSnack('Kurir berhasil ditugaskan untuk $_selectedResiForAction!');
      await _loadData();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPaket = _daftarPaket.where((p) {
      final resi = (p['noResi'] ?? '').toString().toLowerCase();
      final penerima = (p['namaPenerima'] ?? '').toString().toLowerCase();
      return resi.contains(_searchQuery.toLowerCase()) ||
          penerima.contains(_searchQuery.toLowerCase());
    }).toList();

    final menungguCount = _daftarPaket.where((p) {
      final status = (p['statusTerkini'] ?? '').toString().toLowerCase();
      return status.contains('menunggu') || status.contains('proses');
    }).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.navyPrimary),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                child: _buildBodyByTab(filteredPaket, menungguCount),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (i) => setState(() => _selectedNavIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.navyPrimary,
        unselectedItemColor: AppColors.textMuted,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Paket',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Kurir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Akun',
          ),
        ],
      ),
    );
  }

  Widget _buildBodyByTab(
    List<Map<String, dynamic>> filteredPaket,
    int menungguCount,
  ) {
    switch (_selectedNavIndex) {
      case 1:
        return const AdminPaketScreen();
      case 2:
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Daftar Kurir',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (_daftarKurir.isEmpty)
              const Text('Belum ada data kurir terdaftar.'),
            ..._daftarKurir.map((k) {
              final tersedia =
                  k['statusKetersediaan'] == true ||
                  k['statusKetersediaan'] == 1;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGray,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (k['namaLengkap'] ?? 'Kurir').toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          (k['platKendaraan'] ?? '-').toString(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: tersedia
                            ? AppColors.badgeGreenBg
                            : AppColors.yellowSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tersedia ? 'Aktif' : 'Sibuk',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tersedia
                              ? AppColors.badgeGreenText
                              : AppColors.yellowText,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      case 3:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Akun Petugas Gudang',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGray,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.navyPrimary,
                      child: Icon(
                        Icons.warehouse,
                        color: AppColors.yellowAccent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adminNama,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'Role: PetugasGudang',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Keluar / Logout',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ADMIN POS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ringkasan hari ini',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Petugas: $_adminNama',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _loadData,
                    icon: const Icon(
                      Icons.refresh,
                      color: AppColors.navyPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.navyPrimary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengiriman tetap terkendali.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem(
                          value: '${_daftarPaket.length}',
                          label: 'Total paket',
                        ),
                        _StatItem(
                          value: '${_daftarKurir.length}',
                          label: 'Kurir aktif',
                        ),
                        _StatItem(value: '$menungguCount', label: 'Menunggu'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daftar paket',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _selectedNavIndex = 1),
                    child: const Text(
                      'Lihat semua',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Cari resi atau penerima',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              if (filteredPaket.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Belum ada paket ditemukan.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...filteredPaket
                    .take(2)
                    .map((paket) => _AdminPaketCard(paket: paket)),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGray,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Input Paket Baru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Resi dibuat otomatis oleh server.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Text(
                      'ID Pelanggan (Pengirim)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInputField(_idPelangganController, 'Contoh: 2'),
                    const SizedBox(height: 12),
                    const SizedBox(height: 16),
                    const Text(
                      'Nama penerima',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInputField(_namaController, 'Nabila Putri'),
                    const SizedBox(height: 12),
                    const Text(
                      'Alamat tujuan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInputField(
                      _alamatController,
                      'Jl. Keputih Tegal No. 18, Surabaya',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Berat paket (kg)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _beratController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.borderLight,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Layanan',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<bool>(
                                    value: _isExpress,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(
                                        value: false,
                                        child: Text('Reguler'),
                                      ),
                                      DropdownMenuItem(
                                        value: true,
                                        child: Text('Express'),
                                      ),
                                    ],
                                    onChanged: (val) => setState(
                                      () => _isExpress = val ?? false,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ServiceChoiceCard(
                            title: 'Reguler',
                            subtitle: '2-3 hari',
                            isSelected: !_isExpress,
                            onTap: () => setState(() => _isExpress = false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ServiceChoiceCard(
                            title: 'Express',
                            subtitle: '1 hari',
                            isSelected: _isExpress,
                            onTap: () => setState(() => _isExpress = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ESTIMASI ONGKIR OTOMATIS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rp$_estimasiOngkir',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '$_beratVal kg → ${_beratVal.ceil()} kg × Rp${_isExpress ? "18.000" : "10.000"}/kg',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.check,
                            color: AppColors.badgeGreenText,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _simpanPaketBaru,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.yellowAccent,
                          foregroundColor: AppColors.navyPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text(
                          'Simpan & Buat Resi',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Penugasan & transit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              if (_daftarPaket.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedResiForAction,
                      isExpanded: true,
                      items: _daftarPaket
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p['noResi'].toString(),
                              child: Text(
                                '${p['noResi']} · ${p['namaPenerima']}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedResiForAction = v),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (_daftarKurir.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedKurirId,
                      isExpanded: true,
                      items: _daftarKurir
                          .map(
                            (k) => DropdownMenuItem<int>(
                              value: int.tryParse(k['idPengguna'].toString()),
                              child: Text(
                                '${k['namaLengkap'] ?? 'Kurir'} (${k['platKendaraan'] ?? '-'})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedKurirId = v),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _tugaskanKurir,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text(
                    'Tugaskan Kurir',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildInputField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.yellowAccent,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _AdminPaketCard extends StatelessWidget {
  final Map<String, dynamic> paket;
  const _AdminPaketCard({required this.paket});

  @override
  Widget build(BuildContext context) {
    final status = (paket['statusTerkini'] ?? 'Menunggu Penjemputan')
        .toString();
    final isPerjalanan =
        status.toLowerCase().contains('perjalanan') ||
        status.toLowerCase().contains('antar');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(16),
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
                (paket['noResi'] ?? '-').toString(),
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
            (paket['namaPenerima'] ?? '-').toString(),
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
                  (paket['alamatTujuan'] ?? '-').toString(),
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
                (paket['jenisPaket'] ?? 'Reguler').toString(),
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
        ],
      ),
    );
  }
}

class _ServiceChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServiceChoiceCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyPrimary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.navyPrimary : AppColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
