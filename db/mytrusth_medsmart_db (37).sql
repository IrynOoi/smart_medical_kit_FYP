-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jun 16, 2026 at 11:57 AM
-- Server version: 10.11.16-MariaDB-cll-lve
-- PHP Version: 8.4.21

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `mytrusth_medsmart_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `adherence_logs`
--

CREATE TABLE `adherence_logs` (
  `adlog_id` int(11) NOT NULL,
  `prescription_id` int(11) NOT NULL,
  `device_id` int(11) NOT NULL,
  `scheduled_time` datetime NOT NULL,
  `dispensed_time` datetime DEFAULT NULL,
  `status` enum('PENDING','TAKEN','MISSED','SNOOZED') DEFAULT 'PENDING',
  `recorded_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `adherence_logs`
--

INSERT INTO `adherence_logs` (`adlog_id`, `prescription_id`, `device_id`, `scheduled_time`, `dispensed_time`, `status`, `recorded_at`) VALUES
(7, 2, 1, '2026-05-05 00:21:46', NULL, 'MISSED', '2026-05-06 00:21:46'),
(8, 2, 1, '2026-05-04 00:21:46', NULL, 'TAKEN', '2026-05-06 00:21:46'),
(9, 2, 1, '2026-05-06 02:21:46', '2026-05-13 21:11:37', 'TAKEN', '2026-05-06 00:21:46'),
(10, 2, 1, '2026-05-06 08:21:46', '2026-05-13 21:13:54', 'TAKEN', '2026-05-06 00:21:46'),
(12, 2, 1, '2026-05-17 01:29:00', '2026-05-17 01:29:48', 'TAKEN', '2026-05-17 01:29:28'),
(13, 2, 1, '2026-05-17 01:36:00', '2026-05-17 02:02:51', 'TAKEN', '2026-05-17 01:36:28'),
(14, 2, 1, '2026-05-17 22:56:00', '2026-05-17 22:57:24', 'TAKEN', '2026-05-17 22:57:00'),
(15, 9, 1, '2026-05-17 23:10:00', '2026-05-17 23:11:21', 'TAKEN', '2026-05-17 23:11:00'),
(16, 8, 1, '2026-05-19 21:53:00', '2026-05-19 21:53:36', 'TAKEN', '2026-05-19 21:53:07'),
(17, 2, 1, '2026-05-19 21:56:00', '2026-05-19 21:56:36', 'TAKEN', '2026-05-19 21:56:07'),
(18, 9, 1, '2026-05-20 08:36:00', '2026-05-20 08:36:46', 'TAKEN', '2026-05-20 08:36:18'),
(19, 9, 1, '2026-05-20 08:45:00', '2026-05-20 08:47:33', 'TAKEN', '2026-05-20 08:45:18'),
(20, 2, 1, '2026-05-20 11:20:00', '2026-05-20 11:23:13', 'TAKEN', '2026-05-20 11:20:13'),
(21, 9, 1, '2026-05-20 11:53:00', NULL, 'MISSED', '2026-05-20 11:53:28'),
(22, 2, 1, '2026-05-20 12:21:00', NULL, 'MISSED', '2026-05-20 12:21:35'),
(23, 2, 1, '2026-05-20 12:36:00', NULL, 'MISSED', '2026-05-20 12:36:41'),
(24, 2, 1, '2026-05-20 12:56:00', NULL, 'MISSED', '2026-05-20 12:57:20'),
(25, 2, 1, '2026-05-20 13:05:00', '2026-05-20 13:05:25', 'TAKEN', '2026-05-20 13:04:20'),
(26, 2, 1, '2026-05-20 13:17:00', '2026-05-20 13:17:11', 'TAKEN', '2026-05-20 13:16:43'),
(27, 2, 1, '2026-05-20 13:22:00', NULL, 'MISSED', '2026-05-20 13:22:43'),
(28, 2, 1, '2026-05-20 13:53:00', NULL, 'MISSED', '2026-05-20 13:52:12'),
(29, 2, 1, '2026-05-20 13:57:00', '2026-05-20 13:57:17', 'TAKEN', '2026-05-20 13:56:12'),
(30, 2, 1, '2026-05-20 15:27:00', NULL, 'MISSED', '2026-05-20 15:26:46'),
(31, 2, 1, '2026-05-20 15:53:00', '2026-05-20 15:53:22', 'TAKEN', '2026-05-20 15:52:13'),
(32, 8, 1, '2026-05-20 21:57:00', NULL, 'MISSED', '2026-05-20 21:56:12'),
(33, 2, 1, '2026-05-20 22:40:00', NULL, 'MISSED', '2026-05-20 22:39:53'),
(34, 2, 1, '2026-05-20 23:46:00', NULL, 'MISSED', '2026-05-20 23:45:54'),
(35, 9, 1, '2026-05-23 11:53:00', NULL, 'MISSED', '2026-05-23 11:52:58'),
(36, 2, 1, '2026-05-23 13:43:00', NULL, 'MISSED', '2026-05-23 13:43:00'),
(37, 9, 1, '2026-05-25 11:53:00', NULL, 'MISSED', '2026-05-25 11:52:43'),
(38, 2, 1, '2026-05-25 13:43:00', NULL, 'MISSED', '2026-05-25 13:42:59'),
(39, 9, 1, '2026-05-26 11:53:00', '2026-05-26 22:46:42', 'TAKEN', '2026-05-26 11:52:47'),
(40, 2, 1, '2026-05-26 13:43:00', '2026-05-26 22:46:53', 'TAKEN', '2026-05-26 13:42:47'),
(41, 8, 1, '2026-05-26 21:57:00', '2026-05-26 22:47:05', 'TAKEN', '2026-05-26 21:56:55'),
(42, 2, 1, '2026-05-29 13:43:00', '2026-05-29 14:05:18', 'TAKEN', '2026-05-29 13:42:31'),
(43, 10, 1, '2026-06-02 20:39:00', '2026-06-02 20:39:12', 'TAKEN', '2026-06-02 20:38:11'),
(44, 8, 1, '2026-06-02 21:57:00', NULL, 'MISSED', '2026-06-02 21:56:11'),
(45, 2, 1, '2026-06-03 00:10:00', NULL, 'MISSED', '2026-06-03 00:09:33'),
(46, 2, 1, '2026-06-03 00:40:00', NULL, 'MISSED', '2026-06-03 00:39:48'),
(47, 10, 1, '2026-06-04 20:39:00', '2026-06-05 01:17:09', 'TAKEN', '2026-06-04 20:40:54'),
(48, 8, 1, '2026-06-04 21:57:00', '2026-06-05 01:17:23', 'TAKEN', '2026-06-04 21:56:49'),
(49, 2, 1, '2026-06-05 00:40:00', NULL, 'MISSED', '2026-06-05 00:39:52'),
(50, 9, 1, '2026-06-05 00:57:00', NULL, 'MISSED', '2026-06-05 00:56:10'),
(51, 9, 1, '2026-06-05 01:28:00', NULL, 'MISSED', '2026-06-05 01:27:10'),
(52, 9, 1, '2026-06-05 08:46:00', NULL, 'MISSED', '2026-06-05 08:45:41'),
(53, 9, 1, '2026-06-05 08:50:00', NULL, 'MISSED', '2026-06-05 08:49:41'),
(54, 9, 1, '2026-06-05 09:05:00', '2026-06-05 09:05:18', 'TAKEN', '2026-06-05 09:04:40'),
(55, 9, 1, '2026-06-05 09:12:00', '2026-06-05 09:12:18', 'TAKEN', '2026-06-05 09:11:41'),
(56, 9, 1, '2026-06-05 09:28:00', '2026-06-05 09:28:17', 'TAKEN', '2026-06-05 09:27:40'),
(57, 2, 1, '2026-06-05 09:33:00', NULL, 'MISSED', '2026-06-05 09:32:40'),
(58, 10, 1, '2026-06-07 20:39:00', NULL, 'MISSED', '2026-06-07 20:38:38'),
(59, 9, 1, '2026-06-09 02:03:00', NULL, 'MISSED', '2026-06-09 02:02:26'),
(60, 9, 1, '2026-06-09 13:20:00', '2026-06-09 13:24:43', 'TAKEN', '2026-06-09 13:24:43'),
(61, 9, 1, '2026-06-09 14:30:00', '2026-06-09 14:45:49', 'TAKEN', '2026-06-09 14:29:20'),
(62, 9, 1, '2026-06-11 00:35:00', NULL, 'MISSED', '2026-06-11 00:34:39'),
(63, 9, 1, '2026-06-11 00:45:00', '2026-06-11 00:45:41', 'TAKEN', '2026-06-11 00:44:39'),
(64, 10, 1, '2026-06-11 20:39:00', '2026-06-11 23:41:08', 'TAKEN', '2026-06-11 20:38:56'),
(65, 8, 1, '2026-06-11 21:57:00', NULL, 'MISSED', '2026-06-11 21:56:33'),
(66, 9, 1, '2026-06-12 00:45:00', '2026-06-12 00:45:17', 'TAKEN', '2026-06-12 00:44:44'),
(67, 10, 1, '2026-06-12 20:39:00', '2026-06-12 20:39:13', 'TAKEN', '2026-06-12 20:38:41'),
(68, 9, 1, '2026-06-13 00:45:00', '2026-06-13 00:45:05', 'TAKEN', '2026-06-13 00:44:41'),
(69, 2, 1, '2026-06-13 19:05:00', '2026-06-13 19:05:54', 'TAKEN', '2026-06-13 19:04:20'),
(70, 2, 1, '2026-06-13 19:15:00', '2026-06-13 19:21:15', 'TAKEN', '2026-06-13 19:14:20'),
(71, 2, 1, '2026-06-13 19:43:00', '2026-06-13 19:43:09', 'TAKEN', '2026-06-13 19:42:20'),
(72, 2, 1, '2026-06-13 20:07:00', '2026-06-13 20:08:55', 'TAKEN', '2026-06-13 20:06:11'),
(73, 10, 1, '2026-06-13 20:39:00', NULL, 'MISSED', '2026-06-13 20:38:30'),
(74, 2, 1, '2026-06-13 21:55:00', '2026-06-13 21:55:36', 'TAKEN', '2026-06-13 21:54:28'),
(75, 9, 1, '2026-06-14 00:50:00', '2026-06-14 00:50:13', 'TAKEN', '2026-06-14 00:49:28'),
(76, 10, 1, '2026-06-14 20:39:00', '2026-06-14 20:39:09', 'TAKEN', '2026-06-14 20:38:56'),
(77, 2, 1, '2026-06-14 21:55:00', '2026-06-14 21:56:35', 'TAKEN', '2026-06-14 21:54:56'),
(78, 10, 1, '2026-06-14 22:50:00', NULL, 'MISSED', '2026-06-14 22:49:56'),
(79, 9, 1, '2026-06-15 10:50:00', '2026-06-15 10:53:41', 'TAKEN', '2026-06-15 10:49:21'),
(80, 9, 1, '2026-06-15 11:08:00', NULL, 'MISSED', '2026-06-15 11:07:21'),
(81, 11, 1, '2026-06-15 21:10:00', NULL, 'MISSED', '2026-06-15 21:09:29'),
(82, 11, 1, '2026-06-15 21:20:00', NULL, 'MISSED', '2026-06-15 21:19:29'),
(83, 11, 1, '2026-06-15 21:46:00', NULL, 'MISSED', '2026-06-15 21:45:29'),
(84, 2, 1, '2026-06-15 21:55:00', '2026-06-15 21:55:14', 'TAKEN', '2026-06-15 21:54:29'),
(85, 10, 1, '2026-06-15 22:50:00', NULL, 'MISSED', '2026-06-15 22:49:29'),
(86, 10, 1, '2026-06-16 10:03:00', '2026-06-16 10:04:18', 'TAKEN', '2026-06-16 10:02:48');

-- --------------------------------------------------------

--
-- Table structure for table `ai_adherence_prediction`
--

CREATE TABLE `ai_adherence_prediction` (
  `ad_id` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `prediction_score` decimal(5,2) DEFAULT NULL,
  `risk_level` enum('LOW','MEDIUM','HIGH') DEFAULT NULL,
  `predicted_at` datetime DEFAULT current_timestamp(),
  `features_used` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`features_used`))
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `ai_adherence_prediction`
--

INSERT INTO `ai_adherence_prediction` (`ad_id`, `patient_id`, `prediction_score`, `risk_level`, `predicted_at`, `features_used`) VALUES
(1, 2, 51.05, 'HIGH', '2026-06-16 10:55:56', '{\"age\": 81, \"day_of_week\": \"Tuesday\", \"time_of_day\": \"Morning\", \"recent_history\": [0.0, 1.0, 0.0], \"forget_probability_raw\": 0.5105184117226838, \"ai_type\": \"Hybrid (LSTM + RF)\"}'),
(2, 3, 36.06, 'MEDIUM', '2026-06-16 10:55:56', '{\"age\": 77, \"day_of_week\": \"Tuesday\", \"time_of_day\": \"Morning\", \"recent_history\": [1.0, 0.0, 1.0], \"forget_probability_raw\": 0.36063301904420386, \"ai_type\": \"Hybrid (LSTM + RF)\"}'),
(156, 19, 34.18, 'MEDIUM', '2026-06-16 10:55:56', '{\"age\": 30, \"day_of_week\": \"Tuesday\", \"time_of_day\": \"Morning\", \"recent_history\": [0.0, 0.0, 0.0], \"forget_probability_raw\": 0.3418485485622403, \"ai_type\": \"Hybrid (LSTM + RF)\"}');

-- --------------------------------------------------------

--
-- Table structure for table `caregiver`
--

CREATE TABLE `caregiver` (
  `caregiver_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `caregiver`
--

INSERT INTO `caregiver` (`caregiver_id`) VALUES
(1),
(18);

-- --------------------------------------------------------

--
-- Table structure for table `iot_device`
--

CREATE TABLE `iot_device` (
  `device_id` int(11) NOT NULL,
  `device_serial` varchar(100) NOT NULL,
  `last_reported_battery` int(11) DEFAULT 100,
  `last_known_ip` varchar(45) DEFAULT NULL,
  `last_battery_report` datetime DEFAULT NULL,
  `wifi_rssi` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `iot_device`
--

INSERT INTO `iot_device` (`device_id`, `device_serial`, `last_reported_battery`, `last_known_ip`, `last_battery_report`, `wifi_rssi`) VALUES
(1, 'DISP-1', 100, '172.20.10.4', '2026-06-16 10:32:25', -23);

-- --------------------------------------------------------

--
-- Table structure for table `medications`
--

CREATE TABLE `medications` (
  `medication_id` int(11) NOT NULL,
  `medication_name` varchar(100) NOT NULL,
  `current_inventory` int(11) DEFAULT 0,
  `refill_threshold` int(11) DEFAULT 5,
  `device_id` int(11) DEFAULT NULL,
  `motor_slot` int(11) DEFAULT NULL CHECK (`motor_slot` in (1,2,3)),
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `medications`
--

INSERT INTO `medications` (`medication_id`, `medication_name`, `current_inventory`, `refill_threshold`, `device_id`, `motor_slot`, `created_at`, `updated_at`) VALUES
(1, 'Aspirin123', 0, 5, 1, 1, '2026-05-05 15:33:23', '2026-06-15 21:00:19'),
(2, 'Lisinopril', 6, 5, 1, 3, '2026-05-05 15:33:23', '2026-06-16 10:04:18'),
(3, 'Metformin', 3, 10, 1, 2, '2026-05-05 15:33:23', '2026-06-15 21:55:14');

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `notification_id` int(11) NOT NULL,
  `recipient_id` int(11) DEFAULT NULL,
  `title` varchar(255) NOT NULL,
  `message` mediumtext NOT NULL,
  `type` varchar(50) DEFAULT 'REMINDER',
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `notifications`
--

INSERT INTO `notifications` (`notification_id`, `recipient_id`, `title`, `message`, `type`, `is_read`, `created_at`) VALUES
(132, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-06-11 08:39 PM.', 'REMINDER', 1, '2026-06-11 20:29:56'),
(133, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-11 09:57 PM.', 'REMINDER', 0, '2026-06-11 21:51:53'),
(136, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-12 12:45 AM.', 'REMINDER', 1, '2026-06-12 00:35:44'),
(138, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-06-12 08:39 PM.', 'REMINDER', 1, '2026-06-12 20:29:41'),
(139, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-13 12:45 AM.', 'REMINDER', 1, '2026-06-13 00:35:41'),
(142, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-06-13 07:05 PM.', 'REMINDER', 1, '2026-06-13 19:00:20'),
(144, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-06-13 07:15 PM.', 'REMINDER', 1, '2026-06-13 19:09:20'),
(146, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-06-13 07:43 PM.', 'REMINDER', 1, '2026-06-13 19:39:20'),
(148, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-06-13 08:07 PM.', 'REMINDER', 1, '2026-06-13 20:03:11'),
(150, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-06-13 08:39 PM.', 'REMINDER', 1, '2026-06-13 20:29:30'),
(151, 1, 'Medicine Out of Stock', 'Aspirin123 is out of stock for: Mei Ling Tan. Please restock immediately.', 'OUT_OF_STOCK', 1, '2026-06-15 10:53:42'),
(152, 1, 'Medicine Low Stock', 'Metformin is running low for: Mei Ling Tan. Please restock soon.', 'LOW_STOCK', 0, '2026-06-16 10:58:08'),
(153, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-06-13 09:55 PM.', 'REMINDER', 1, '2026-06-13 21:51:28'),
(154, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-14 12:45 AM.', 'REMINDER', 1, '2026-06-14 00:35:29'),
(155, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-14 12:50 AM.', 'REMINDER', 1, '2026-06-14 00:42:28'),
(156, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-06-14 08:39 PM.', 'REMINDER', 1, '2026-06-14 20:29:56'),
(157, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-06-14 09:55 PM.', 'REMINDER', 1, '2026-06-14 21:45:56'),
(158, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-06-14 10:50 PM.', 'REMINDER', 1, '2026-06-14 22:47:55'),
(159, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-15 10:50 AM.', 'REMINDER', 0, '2026-06-15 10:40:21'),
(160, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-15 11:08 AM.', 'REMINDER', 0, '2026-06-15 11:05:21'),
(161, 18, 'Medicine Out of Stock', 'Aspirin123 is out of stock for: test_patient. Please restock immediately.', 'OUT_OF_STOCK', 0, '2026-06-15 21:42:53'),
(162, 19, 'New Prescription Added', 'Your caregiver has added a new prescription for Aspirin123. Please check your updated schedule.', 'ALERT', 1, '2026-06-15 21:00:19'),
(163, 18, 'Medicine Low Stock', 'Metformin is running low for: Device DISP-1. Please restock soon.', 'LOW_STOCK', 0, '2026-06-15 21:40:53'),
(164, 18, 'Medicine Low Stock', 'Metformin is running low for: Device DISP-1. Please restock soon.', 'LOW_STOCK', 0, '2026-06-15 21:00:25'),
(165, 19, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-15 09:10 PM.', 'REMINDER', 1, '2026-06-15 21:07:29'),
(166, 19, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-15 09:20 PM.', 'REMINDER', 1, '2026-06-15 21:16:29'),
(167, 19, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-15 09:46 PM.', 'REMINDER', 1, '2026-06-15 21:43:29'),
(168, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-06-15 09:55 PM.', 'REMINDER', 0, '2026-06-15 21:45:29'),
(169, 1, 'Medicine Out of Stock', 'Aspirin123 is out of stock for: Ahmad Abdullah, Mei Ling Tan, test_patient. Please restock immediately.', 'OUT_OF_STOCK', 0, '2026-06-16 10:58:08'),
(170, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-06-15 10:50 PM.', 'REMINDER', 0, '2026-06-15 22:40:29'),
(171, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-06-16 10:03 AM.', 'REMINDER', 0, '2026-06-16 09:59:49'),
(172, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-06-16 11:08 AM.', 'REMINDER', 0, '2026-06-16 10:58:48');

-- --------------------------------------------------------

--
-- Table structure for table `patient`
--

CREATE TABLE `patient` (
  `patient_id` int(11) NOT NULL,
  `medical_notes` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `patient`
--

INSERT INTO `patient` (`patient_id`, `medical_notes`) VALUES
(2, NULL),
(3, 'Type 2 diabetes, requires insulin monitoring.'),
(4, NULL),
(16, ''),
(19, '');

-- --------------------------------------------------------

--
-- Table structure for table `patient_caregiver_mapping`
--

CREATE TABLE `patient_caregiver_mapping` (
  `mapping_id` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `caregiver_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `patient_caregiver_mapping`
--

INSERT INTO `patient_caregiver_mapping` (`mapping_id`, `patient_id`, `caregiver_id`) VALUES
(2, 2, 1),
(3, 3, 1),
(4, 4, 1),
(21, 19, 1),
(20, 19, 18);

-- --------------------------------------------------------

--
-- Table structure for table `prescription_config`
--

CREATE TABLE `prescription_config` (
  `prescription_id` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `medication_id` int(11) NOT NULL,
  `dosage_tablet` decimal(10,2) NOT NULL,
  `dispense_schedule` varchar(50) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `prescription_config`
--

INSERT INTO `prescription_config` (`prescription_id`, `patient_id`, `medication_id`, `dosage_tablet`, `dispense_schedule`, `start_date`, `end_date`, `created_at`, `updated_at`) VALUES
(2, 3, 3, 1.00, '55 21 * * *', '2026-05-05', NULL, '2026-05-05 22:31:02', '2026-06-13 21:50:50'),
(8, 2, 1, 1.00, '57 21 * * 2,3,4', '2026-05-14', NULL, '2026-05-14 21:49:17', '2026-05-20 11:48:27'),
(9, 3, 1, 1.00, '08 11 * * *', '2026-05-14', NULL, '2026-05-14 22:57:29', '2026-06-15 11:04:22'),
(10, 3, 2, 1.00, '03 10 * * *', '2026-06-02', NULL, '2026-06-02 20:16:44', '2026-06-16 09:59:25'),
(11, 19, 1, 1.00, '46 21 * * *', '2026-06-15', NULL, '2026-06-15 21:00:18', '2026-06-15 21:42:53');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` varchar(20) NOT NULL CHECK (`role` in ('patient','caregiver')),
  `full_name` varchar(100) NOT NULL,
  `phone_no` varchar(20) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `gender` varchar(10) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `profile_photo` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `email`, `password`, `role`, `full_name`, `phone_no`, `address`, `gender`, `date_of_birth`, `profile_photo`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'caregiver1@example.com', '123456', 'caregiver', 'Jane Smith', '+60197775462', '123 Main St, KL', 'Female', '1980-03-21', 'http://reluctant-scrambled-badge.ngrok-free.dev/static/profiles/caregiver_1_scaled_6d8a90df45d69bb2f4ca4dfb8257e0b48a50ee56.jpg', 1, '2026-04-17 00:29:27', '2026-04-18 16:20:43'),
(2, 'ahmad125@gmail.com', 'hash2', 'patient', 'Ahmad Abdullah', '+60110000001', 'No 1, Jalan SS2, jalan keris 28', 'Male', '1945-05-15', 'https://randomuser.me/api/portraits/men/1.jpg', 1, '2026-04-17 00:29:27', '2026-06-16 10:50:18'),
(3, 'patient2@example.com', '123456', 'patient', 'Mei Ling Tan', '+60110000002', '22, Lorong Gombak, KL', 'Female', '1948-07-20', '/static/profiles/patient_3_scaled_1000020585.jpg', 1, '2026-04-17 00:29:27', '2026-05-29 16:43:21'),
(4, 'ooi14@gmail.com', '123456', 'patient', 'irynooi', '0197560221', '2,jalan keris 28,Taman puteri wangsa', 'Female', '1979-03-20', NULL, 1, '2026-05-06 16:10:38', '2026-05-08 19:39:20'),
(16, 'testing12@gmail.com', '123456', 'patient', 'hii', '0197560221', 'johor', 'Female', '1996-06-16', NULL, 1, '2026-06-02 19:15:42', '2026-06-02 19:15:42'),
(18, 'testcg@gmail.com', '123456', 'caregiver', 'test_caregiver', '0197560221', 'johor ', 'Male', '2006-06-20', NULL, 1, '2026-06-15 20:53:24', '2026-06-15 20:57:55'),
(19, 'test_patient@gmail.com', '123456', 'patient', 'test_patient', '0197560221', 'johor', 'Male', '1996-06-07', NULL, 1, '2026-06-15 20:59:27', '2026-06-15 20:59:27');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `adherence_logs`
--
ALTER TABLE `adherence_logs`
  ADD PRIMARY KEY (`adlog_id`),
  ADD KEY `prescription_id` (`prescription_id`),
  ADD KEY `device_id` (`device_id`);

--
-- Indexes for table `ai_adherence_prediction`
--
ALTER TABLE `ai_adherence_prediction`
  ADD PRIMARY KEY (`ad_id`),
  ADD UNIQUE KEY `unique_patient_latest` (`patient_id`);

--
-- Indexes for table `caregiver`
--
ALTER TABLE `caregiver`
  ADD PRIMARY KEY (`caregiver_id`);

--
-- Indexes for table `iot_device`
--
ALTER TABLE `iot_device`
  ADD PRIMARY KEY (`device_id`),
  ADD UNIQUE KEY `device_serial` (`device_serial`);

--
-- Indexes for table `medications`
--
ALTER TABLE `medications`
  ADD PRIMARY KEY (`medication_id`),
  ADD UNIQUE KEY `medication_name` (`medication_name`),
  ADD UNIQUE KEY `unique_device_motor` (`device_id`,`motor_slot`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`notification_id`),
  ADD KEY `idx_recipient` (`recipient_id`);

--
-- Indexes for table `patient`
--
ALTER TABLE `patient`
  ADD PRIMARY KEY (`patient_id`);

--
-- Indexes for table `patient_caregiver_mapping`
--
ALTER TABLE `patient_caregiver_mapping`
  ADD PRIMARY KEY (`mapping_id`),
  ADD UNIQUE KEY `unique_patient_caregiver` (`patient_id`,`caregiver_id`),
  ADD KEY `caregiver_id` (`caregiver_id`);

--
-- Indexes for table `prescription_config`
--
ALTER TABLE `prescription_config`
  ADD PRIMARY KEY (`prescription_id`),
  ADD KEY `patient_id` (`patient_id`),
  ADD KEY `medication_id` (`medication_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `adherence_logs`
--
ALTER TABLE `adherence_logs`
  MODIFY `adlog_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=87;

--
-- AUTO_INCREMENT for table `ai_adherence_prediction`
--
ALTER TABLE `ai_adherence_prediction`
  MODIFY `ad_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=177;

--
-- AUTO_INCREMENT for table `iot_device`
--
ALTER TABLE `iot_device`
  MODIFY `device_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `medications`
--
ALTER TABLE `medications`
  MODIFY `medication_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `notification_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=173;

--
-- AUTO_INCREMENT for table `patient_caregiver_mapping`
--
ALTER TABLE `patient_caregiver_mapping`
  MODIFY `mapping_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `prescription_config`
--
ALTER TABLE `prescription_config`
  MODIFY `prescription_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `adherence_logs`
--
ALTER TABLE `adherence_logs`
  ADD CONSTRAINT `adherence_logs_ibfk_1` FOREIGN KEY (`prescription_id`) REFERENCES `prescription_config` (`prescription_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `adherence_logs_ibfk_2` FOREIGN KEY (`device_id`) REFERENCES `iot_device` (`device_id`) ON DELETE CASCADE;

--
-- Constraints for table `ai_adherence_prediction`
--
ALTER TABLE `ai_adherence_prediction`
  ADD CONSTRAINT `ai_adherence_prediction_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `patient` (`patient_id`) ON DELETE CASCADE;

--
-- Constraints for table `caregiver`
--
ALTER TABLE `caregiver`
  ADD CONSTRAINT `caregiver_ibfk_1` FOREIGN KEY (`caregiver_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `medications`
--
ALTER TABLE `medications`
  ADD CONSTRAINT `medications_ibfk_1` FOREIGN KEY (`device_id`) REFERENCES `iot_device` (`device_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`recipient_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `patient`
--
ALTER TABLE `patient`
  ADD CONSTRAINT `patient_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `patient_caregiver_mapping`
--
ALTER TABLE `patient_caregiver_mapping`
  ADD CONSTRAINT `patient_caregiver_mapping_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `patient` (`patient_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `patient_caregiver_mapping_ibfk_2` FOREIGN KEY (`caregiver_id`) REFERENCES `caregiver` (`caregiver_id`) ON DELETE CASCADE;

--
-- Constraints for table `prescription_config`
--
ALTER TABLE `prescription_config`
  ADD CONSTRAINT `prescription_config_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `patient` (`patient_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `prescription_config_ibfk_2` FOREIGN KEY (`medication_id`) REFERENCES `medications` (`medication_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
