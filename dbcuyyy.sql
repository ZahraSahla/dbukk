-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Feb 08, 2026 at 07:15 AM
-- Server version: 8.4.3
-- PHP Version: 8.3.26

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `db_peminjaman_alat`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_proses_pinjam` (IN `p_id_user` INT, IN `p_id_alat` INT, IN `p_tgl_pinjam` DATE, IN `p_tgl_kembali` DATE)   BEGIN
    DECLARE v_stok INT;
    
    -- 1. Cek Stok Alat Terkini (Lock for Update untuk mencegah Race Condition)
    SELECT stok INTO v_stok FROM alat WHERE id_alat = p_id_alat FOR UPDATE;
    
    -- 2. Logika Pengecekan
    IF v_stok > 0 THEN
        -- Mulai Transaksi
        START TRANSACTION;
        
        -- Kurangi Stok (Booking Alat)
        UPDATE alat SET stok = stok - 1 WHERE id_alat = p_id_alat;
        
        -- Masukkan Data Peminjaman dengan status 'PENDING'
        INSERT INTO peminjaman (id_user, id_alat, tgl_pinjam, tgl_kembali, status, denda) 
        VALUES (p_id_user, p_id_alat, p_tgl_pinjam, p_tgl_kembali, 'pending', 0);
        
        -- Simpan Perubahan
        COMMIT;
    ELSE
        -- Jika stok habis, batalkan
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stok alat habis, tidak bisa mengajukan.';
        ROLLBACK;
    END IF;
END$$

--
-- Functions
--
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_hitung_denda` (`tgl_seharusnya` DATE, `tgl_kembali` DATE) RETURNS DECIMAL(10,2) DETERMINISTIC BEGIN
    DECLARE selisih_hari INT;
    DECLARE total_denda DECIMAL(10,2) DEFAULT 0;
    
    -- Hitung selisih hari
    SET selisih_hari = DATEDIFF(tgl_kembali, tgl_seharusnya);
    
    -- Jika terlambat (selisih positif), hitung denda
    IF selisih_hari > 0 THEN
        SET total_denda = selisih_hari * 5000; -- Denda Rp 5.000 per hari
    END IF;
    
    RETURN total_denda;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `alat`
--

CREATE TABLE `alat` (
  `id_alat` int NOT NULL,
  `id_kategori` int DEFAULT NULL,
  `nama_alat` varchar(255) NOT NULL,
  `merk` varchar(100) DEFAULT NULL,
  `stok` int DEFAULT '0',
  `harga_per_hari` decimal(10,2) DEFAULT '0.00',
  `foto` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `alat`
--

INSERT INTO `alat` (`id_alat`, `id_kategori`, `nama_alat`, `merk`, `stok`, `harga_per_hari`, `foto`) VALUES
(1, 1, 'Bor', 'Makita', 2, 20000.00, '1769002164_351.jpg');

-- --------------------------------------------------------

--
-- Table structure for table `kategori`
--

CREATE TABLE `kategori` (
  `id_kategori` int NOT NULL,
  `nama_kategori` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `kategori`
--

INSERT INTO `kategori` (`id_kategori`, `nama_kategori`) VALUES
(1, 'Perkakas');

-- --------------------------------------------------------

--
-- Table structure for table `log_aktivitas`
--

CREATE TABLE `log_aktivitas` (
  `id_log` int NOT NULL,
  `id_user` int DEFAULT NULL,
  `aktivitas` text,
  `waktu` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `log_aktivitas`
--

INSERT INTO `log_aktivitas` (`id_log`, `id_user`, `aktivitas`, `waktu`) VALUES
(1, 1, 'User baru terdaftar: admin', '2026-01-19 13:56:35'),
(2, 2, 'User baru terdaftar: 123', '2026-01-19 14:15:06'),
(3, 3, 'User baru terdaftar: Hanif', '2026-01-19 14:26:33'),
(5, 5, 'User baru terdaftar: zahra', '2026-01-20 02:28:37'),
(6, 6, 'User baru terdaftar: 22', '2026-01-21 13:01:53'),
(7, 7, 'User baru terdaftar: 11', '2026-01-21 13:18:34');

-- --------------------------------------------------------

--
-- Table structure for table `peminjaman`
--

CREATE TABLE `peminjaman` (
  `id_pinjam` int NOT NULL,
  `id_user` int DEFAULT NULL,
  `id_alat` int DEFAULT NULL,
  `tgl_pinjam` date DEFAULT NULL,
  `tgl_kembali` date DEFAULT NULL,
  `biaya_sewa` decimal(10,2) DEFAULT '0.00',
  `tgl_pengembalian_aktual` date DEFAULT NULL,
  `denda` decimal(10,2) DEFAULT '0.00',
  `status` enum('pending','dipinjam','kembali','ditolak') DEFAULT 'pending'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `peminjaman`
--

INSERT INTO `peminjaman` (`id_pinjam`, `id_user`, `id_alat`, `tgl_pinjam`, `tgl_kembali`, `biaya_sewa`, `tgl_pengembalian_aktual`, `denda`, `status`) VALUES
(1, 3, 1, '2026-01-17', '2026-01-18', 0.00, '2026-01-19', 5000.00, 'kembali'),
(2, 3, 1, '2026-01-01', '2026-01-01', 0.00, '2026-01-19', 90000.00, 'kembali'),
(4, 3, 1, '2026-01-17', '2026-01-19', 0.00, '2026-01-19', 0.00, 'kembali'),
(5, 3, 1, '2026-01-12', '2026-01-13', 160.00, '2026-01-20', 35000.00, 'kembali');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id_user` int NOT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `nama_lengkap` varchar(100) DEFAULT NULL,
  `role` enum('admin','petugas','peminjam') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id_user`, `username`, `password`, `nama_lengkap`, `role`) VALUES
(1, 'admin', '$2y$10$lZzbEy4v.c33fyQZqSiVg.YrT0G75aEupYiU0IaSoULBxS4RG4mSa', 'admin', 'petugas'),
(2, '123', '$2y$10$R4si1RfGdcncqLh5g0CkD./LudeaMShA5J1FXBpMibZYHlsAQpfk.', '123', 'admin'),
(3, 'Hanif', '$2y$10$nNnttD2aw3qaqIjwkrjWbOmXTTDsdHTrdm9OSC8paGhhrjs.DmJLS', 'Hanif Farhan N', 'peminjam'),
(5, 'zahra', '$2y$10$NnSsmi35jTWgjLL5.aqyyOB2kaStNHTu1INlkG/wLuCIsiK324D/a', 'Zahra Sahla', 'peminjam'),
(6, '22', '$2y$10$2evQCBr51g0c7PpEl8jEM.en0ObCAuSodLJUY0CPOwKRtVamUZyl6', 'Hanif Farhan Nasrulloh', 'admin'),
(7, '11', '$2y$10$BM/Fua3C7lQqLKwbvBqsAeKcEHs/kh6lq7GqazNcwqC55MWaQM06.', 'Aden', 'peminjam');

--
-- Triggers `users`
--
DELIMITER $$
CREATE TRIGGER `tr_log_user_baru` AFTER INSERT ON `users` FOR EACH ROW BEGIN
    INSERT INTO log_aktivitas (id_user, aktivitas)
    VALUES (NEW.id_user, CONCAT('User baru terdaftar: ', NEW.username));
END
$$
DELIMITER ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `alat`
--
ALTER TABLE `alat`
  ADD PRIMARY KEY (`id_alat`),
  ADD KEY `id_kategori` (`id_kategori`);

--
-- Indexes for table `kategori`
--
ALTER TABLE `kategori`
  ADD PRIMARY KEY (`id_kategori`);

--
-- Indexes for table `log_aktivitas`
--
ALTER TABLE `log_aktivitas`
  ADD PRIMARY KEY (`id_log`),
  ADD KEY `id_user` (`id_user`);

--
-- Indexes for table `peminjaman`
--
ALTER TABLE `peminjaman`
  ADD PRIMARY KEY (`id_pinjam`),
  ADD KEY `id_user` (`id_user`),
  ADD KEY `id_alat` (`id_alat`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id_user`),
  ADD UNIQUE KEY `username` (`username`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `alat`
--
ALTER TABLE `alat`
  MODIFY `id_alat` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `kategori`
--
ALTER TABLE `kategori`
  MODIFY `id_kategori` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `log_aktivitas`
--
ALTER TABLE `log_aktivitas`
  MODIFY `id_log` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `peminjaman`
--
ALTER TABLE `peminjaman`
  MODIFY `id_pinjam` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id_user` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `alat`
--
ALTER TABLE `alat`
  ADD CONSTRAINT `alat_ibfk_1` FOREIGN KEY (`id_kategori`) REFERENCES `kategori` (`id_kategori`) ON DELETE SET NULL;

--
-- Constraints for table `log_aktivitas`
--
ALTER TABLE `log_aktivitas`
  ADD CONSTRAINT `log_aktivitas_ibfk_1` FOREIGN KEY (`id_user`) REFERENCES `users` (`id_user`) ON DELETE CASCADE;

--
-- Constraints for table `peminjaman`
--
ALTER TABLE `peminjaman`
  ADD CONSTRAINT `peminjaman_ibfk_1` FOREIGN KEY (`id_user`) REFERENCES `users` (`id_user`) ON DELETE CASCADE,
  ADD CONSTRAINT `peminjaman_ibfk_2` FOREIGN KEY (`id_alat`) REFERENCES `alat` (`id_alat`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
