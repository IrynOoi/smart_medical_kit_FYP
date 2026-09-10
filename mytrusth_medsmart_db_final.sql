-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Sep 10, 2026 at 01:18 AM
-- Server version: 10.11.19-MariaDB-cll-lve
-- PHP Version: 8.4.24

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
(240, 38, 1, '2026-09-06 00:46:00', '2026-09-06 00:46:11', 'TAKEN', '2026-09-06 00:45:16'),
(241, 40, 1, '2026-09-06 15:37:00', NULL, 'MISSED', '2026-09-06 15:36:27'),
(242, 23, 1, '2026-09-06 17:22:00', NULL, 'MISSED', '2026-09-06 17:21:27'),
(243, 38, 1, '2026-09-07 00:46:00', NULL, 'MISSED', '2026-09-07 00:45:31'),
(244, 39, 1, '2026-09-07 21:12:00', '2026-09-07 22:12:00', 'TAKEN', '2026-09-07 21:11:17'),
(245, 39, 1, '2026-09-07 22:35:00', '2026-09-07 22:37:00', 'TAKEN', '2026-09-07 22:34:22'),
(246, 39, 1, '2026-09-07 22:40:00', '2026-09-07 22:41:24', 'TAKEN', '2026-09-07 22:39:22'),
(247, 38, 1, '2026-09-08 00:46:00', '2026-09-08 00:46:09', 'TAKEN', '2026-09-08 00:45:43'),
(248, 39, 1, '2026-09-08 20:28:00', '2026-09-08 20:28:15', 'TAKEN', '2026-09-08 20:27:30'),
(249, 38, 1, '2026-09-09 00:46:00', '2026-09-09 00:46:13', 'TAKEN', '2026-09-09 00:45:12'),
(250, 34, 1, '2026-09-09 12:14:00', '2026-09-09 12:14:22', 'TAKEN', '2026-09-09 12:13:43');

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
(227, 3, 54.43, 'HIGH', '2026-09-03 01:11:58', '{\"age\": 78, \"day_of_week\": \"Thursday\", \"time_of_day\": \"Evening\", \"recent_history\": [1.0, 0.0, 0.0], \"forget_probability_raw\": 0.5443102126175632, \"ai_type\": \"Hybrid (LSTM + RF)\"}'),
(420, 2, 55.02, 'HIGH', '2026-09-03 02:44:33', '{\"age\": 81, \"day_of_week\": \"Thursday\", \"time_of_day\": \"Evening\", \"recent_history\": [0.0, 1.0, 0.0], \"forget_probability_raw\": 0.5501597306052747, \"ai_type\": \"Hybrid (LSTM + RF)\"}');

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
(18),
(23);

-- --------------------------------------------------------

--
-- Table structure for table `hardware_tickets`
--

CREATE TABLE `hardware_tickets` (
  `ticket_id` int(11) NOT NULL,
  `ticket_code` varchar(32) DEFAULT NULL,
  `device_serial` varchar(64) NOT NULL,
  `device_id` int(11) DEFAULT NULL,
  `issue_category` varchar(128) NOT NULL,
  `notes` text DEFAULT NULL,
  `submitted_by` varchar(128) DEFAULT NULL,
  `technician_name` varchar(128) DEFAULT 'Ooi Xien Xien',
  `status` varchar(32) DEFAULT 'PENDING',
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `hardware_tickets`
--

INSERT INTO `hardware_tickets` (`ticket_id`, `ticket_code`, `device_serial`, `device_id`, `issue_category`, `notes`, `submitted_by`, `technician_name`, `status`, `created_at`) VALUES
(1, 'HW-0001', 'DISP-1', 1, 'General Hardware Maintenance', 'maintainance required', 'caregiver1@example.com', 'Ooi Xien Xien', 'PENDING', '2026-08-30 23:04:04'),
(2, 'HW-0002', 'DISP-1', 1, 'General Hardware Maintenance', 'Maintainance required', 'caregiver1@example.com', 'Ooi Xien Xien', 'PENDING', '2026-09-08 04:01:26'),
(3, 'HW-0003', 'DISP-1', 1, 'Battery Power / Charging Glitch', 'battery broken', 'caregiver1@example.com', 'Ooi Xien Xien', 'PENDING', '2026-09-09 12:25:20');

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
  `wifi_rssi` int(11) DEFAULT NULL,
  `is_awake` tinyint(1) DEFAULT 1,
  `last_power_status_update` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `iot_device`
--

INSERT INTO `iot_device` (`device_id`, `device_serial`, `last_reported_battery`, `last_known_ip`, `last_battery_report`, `wifi_rssi`, `is_awake`, `last_power_status_update`) VALUES
(1, 'DISP-1', 60, '172.20.10.3', '2026-09-09 12:35:38', -64, 1, '2026-09-09 12:35:38');

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
(1, 'Aspirin123', 15, 5, 1, 1, '2026-05-05 15:33:23', '2026-09-09 00:46:13'),
(2, 'Lisinopril', 0, 5, 1, 3, '2026-05-05 15:33:23', '2026-09-09 00:37:35'),
(3, 'Metformin', 7, 10, 1, 2, '2026-05-05 15:33:23', '2026-09-09 12:14:22');

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
(282, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-07-29 05:02 PM.', 'REMINDER', 0, '2026-07-29 16:52:50'),
(283, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-07-29 05:22 PM.', 'REMINDER', 0, '2026-07-29 17:12:50'),
(284, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-07-29 05:29 PM.', 'REMINDER', 0, '2026-07-29 17:19:50'),
(285, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-07-29 05:30 PM.', 'REMINDER', 0, '2026-07-29 17:20:50'),
(286, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-07-29 06:03 PM.', 'REMINDER', 0, '2026-07-29 17:53:50'),
(287, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-08-03 12:14 PM.', 'REMINDER', 0, '2026-08-03 12:04:35'),
(288, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-04 03:06 PM.', 'REMINDER', 0, '2026-08-04 14:56:59'),
(289, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-04 05:02 PM.', 'REMINDER', 0, '2026-08-04 16:52:50'),
(290, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-04 05:22 PM.', 'REMINDER', 0, '2026-08-04 17:12:49'),
(291, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-04 05:29 PM.', 'REMINDER', 0, '2026-08-04 17:19:49'),
(292, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-04 05:30 PM.', 'REMINDER', 0, '2026-08-04 17:20:49'),
(293, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-04 06:03 PM.', 'REMINDER', 0, '2026-08-04 17:53:50'),
(294, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-13 05:02 PM.', 'REMINDER', 0, '2026-08-13 16:52:21'),
(295, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-13 05:22 PM.', 'REMINDER', 0, '2026-08-13 17:12:21'),
(296, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-13 05:29 PM.', 'REMINDER', 0, '2026-08-13 17:19:21'),
(297, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-13 05:30 PM.', 'REMINDER', 0, '2026-08-13 17:20:21'),
(298, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-13 06:03 PM.', 'REMINDER', 0, '2026-08-13 18:01:49'),
(299, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-14 03:06 PM.', 'REMINDER', 0, '2026-08-14 14:56:29'),
(300, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-14 05:02 PM.', 'REMINDER', 0, '2026-08-14 16:52:24'),
(301, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-14 05:22 PM.', 'REMINDER', 0, '2026-08-14 17:12:24'),
(302, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-14 05:29 PM.', 'REMINDER', 0, '2026-08-14 17:19:24'),
(303, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-14 05:30 PM.', 'REMINDER', 0, '2026-08-14 17:20:24'),
(304, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-14 06:03 PM.', 'REMINDER', 0, '2026-08-14 17:53:24'),
(305, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-15 03:06 PM.', 'REMINDER', 0, '2026-08-15 14:56:45'),
(306, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-15 05:02 PM.', 'REMINDER', 0, '2026-08-15 16:53:02'),
(307, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-16 03:06 PM.', 'REMINDER', 0, '2026-08-16 14:56:23'),
(308, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-16 05:02 PM.', 'REMINDER', 0, '2026-08-16 16:52:22'),
(309, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-17 05:02 PM.', 'REMINDER', 0, '2026-08-17 16:52:39'),
(310, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-17 05:22 PM.', 'REMINDER', 0, '2026-08-17 17:12:39'),
(311, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-17 05:29 PM.', 'REMINDER', 0, '2026-08-17 17:19:39'),
(312, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-17 05:30 PM.', 'REMINDER', 0, '2026-08-17 17:20:39'),
(313, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-17 06:03 PM.', 'REMINDER', 0, '2026-08-17 17:53:39'),
(314, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-18 05:02 PM.', 'REMINDER', 0, '2026-08-18 16:52:54'),
(315, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-18 05:22 PM.', 'REMINDER', 0, '2026-08-18 17:12:54'),
(316, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-18 05:29 PM.', 'REMINDER', 0, '2026-08-18 17:19:54'),
(317, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-18 05:30 PM.', 'REMINDER', 0, '2026-08-18 17:20:54'),
(318, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-18 06:03 PM.', 'REMINDER', 0, '2026-08-18 17:53:54'),
(319, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-19 03:06 PM.', 'REMINDER', 0, '2026-08-19 14:56:29'),
(320, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-19 05:02 PM.', 'REMINDER', 0, '2026-08-19 16:52:29'),
(321, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-19 05:22 PM.', 'REMINDER', 0, '2026-08-19 17:12:29'),
(322, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-19 05:29 PM.', 'REMINDER', 0, '2026-08-19 17:19:29'),
(323, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-19 05:30 PM.', 'REMINDER', 0, '2026-08-19 17:20:29'),
(324, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-19 06:03 PM.', 'REMINDER', 0, '2026-08-19 17:53:29'),
(325, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-20 05:02 PM.', 'REMINDER', 0, '2026-08-20 16:52:37'),
(326, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-20 05:22 PM.', 'REMINDER', 0, '2026-08-20 17:12:37'),
(327, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-20 05:29 PM.', 'REMINDER', 0, '2026-08-20 17:19:37'),
(328, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-20 05:30 PM.', 'REMINDER', 0, '2026-08-20 17:20:37'),
(329, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-20 06:03 PM.', 'REMINDER', 0, '2026-08-20 17:53:37'),
(330, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-22 03:06 PM.', 'REMINDER', 0, '2026-08-22 14:56:48'),
(331, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-22 03:37 PM.', 'REMINDER', 0, '2026-08-22 15:33:25'),
(333, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-22 05:22 PM.', 'REMINDER', 0, '2026-08-22 17:12:08'),
(334, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-23 03:06 PM.', 'REMINDER', 0, '2026-08-23 14:59:25'),
(335, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-23 03:26 PM.', 'REMINDER', 0, '2026-08-23 15:16:25'),
(336, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-23 03:37 PM.', 'REMINDER', 0, '2026-08-23 15:27:25'),
(337, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-23 05:22 PM.', 'REMINDER', 0, '2026-08-23 17:12:25'),
(338, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-27 09:12 PM.', 'REMINDER', 0, '2026-08-27 21:08:15'),
(340, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-08-30 05:22 PM.', 'REMINDER', 0, '2026-08-30 17:12:03'),
(341, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-08-30 09:12 PM.', 'REMINDER', 0, '2026-08-30 21:03:37'),
(342, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-09-01 05:22 PM.', 'REMINDER', 0, '2026-09-01 17:12:34'),
(343, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-09-03 12:46 AM.', 'REMINDER', 0, '2026-09-03 00:36:24'),
(344, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-09-04 05:22 PM.', 'REMINDER', 0, '2026-09-04 17:13:00'),
(345, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-09-05 03:37 PM.', 'REMINDER', 0, '2026-09-05 15:27:23'),
(346, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-09-05 05:22 PM.', 'REMINDER', 0, '2026-09-05 17:12:23'),
(347, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-09-05 09:12 PM.', 'REMINDER', 0, '2026-09-05 21:02:22'),
(348, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-09-06 12:46 AM.', 'REMINDER', 0, '2026-09-06 00:36:16'),
(349, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-09-06 03:37 PM.', 'REMINDER', 0, '2026-09-06 15:27:27'),
(350, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Lisinopril at 2026-09-06 05:22 PM.', 'REMINDER', 0, '2026-09-06 17:12:27'),
(351, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-09-07 12:46 AM.', 'REMINDER', 0, '2026-09-07 00:36:31'),
(352, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-09-07 09:12 PM.', 'REMINDER', 0, '2026-09-07 21:02:17'),
(353, 2, 'Medication Reminder', 'Time to take 2 tablet(s) of Aspirin123 at 2026-09-07 10:35 PM.', 'REMINDER', 0, '2026-09-07 22:31:22'),
(354, 16, 'New Prescription Added', 'Your caregiver has added a new prescription for Aspirin123. Please check your updated schedule.', 'ALERT', 0, '2026-09-07 22:49:53'),
(355, 16, 'Prescription Removed', 'Your caregiver has removed your prescription for Aspirin123.', 'ALERT', 0, '2026-09-07 22:50:07'),
(356, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-09-08 12:46 AM.', 'REMINDER', 0, '2026-09-08 00:36:43'),
(368, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin123 at 2026-09-09 12:46 AM.', 'REMINDER', 0, '2026-09-09 00:36:12'),
(369, 1, 'Medicine Low Stock', 'Metformin is running low for: Mei Ling Tan, Ahmad Abdullah. Please restock soon.', 'LOW_STOCK', 0, '2026-09-09 00:37:10'),
(370, 1, 'Medicine Out of Stock', 'Lisinopril is out of stock for: Mei Ling Tan, Ahmad Abdullah. Please restock immediately.', 'OUT_OF_STOCK', 0, '2026-09-09 00:37:36'),
(371, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-09-09 12:14 PM.', 'REMINDER', 0, '2026-09-09 12:04:43');

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
(2, ''),
(3, 'Type 2 diabetes, requires insulin monitoring.'),
(4, NULL),
(16, ''),
(19, ''),
(24, 'extra care'),
(25, ''),
(26, ''),
(27, ''),
(28, ''),
(29, '');

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
(29, 2, 1),
(3, 3, 1),
(30, 4, 1),
(26, 16, 1),
(25, 19, 1),
(20, 19, 18),
(22, 24, 1),
(24, 25, 1),
(23, 26, 1),
(27, 27, 1),
(28, 28, 1);

-- --------------------------------------------------------

--
-- Table structure for table `prescription_config`
--

CREATE TABLE `prescription_config` (
  `prescription_id` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `medication_id` int(11) NOT NULL,
  `dosage_tablet` decimal(10,2) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `prescription_config`
--

INSERT INTO `prescription_config` (`prescription_id`, `patient_id`, `medication_id`, `dosage_tablet`, `start_date`, `end_date`, `created_at`, `updated_at`) VALUES
(21, 3, 1, 1.00, '2026-06-22', '2026-06-21', '2026-06-22 19:10:09', '2026-06-25 14:55:00'),
(23, 3, 2, 1.00, '2026-06-22', NULL, '2026-06-22 19:25:36', '2026-06-24 17:18:36'),
(29, 2, 1, 1.00, '2026-06-22', '2026-08-04', '2026-06-22 19:49:07', '2026-08-22 14:25:07'),
(30, 2, 2, 1.00, '2026-06-22', '2026-08-21', '2026-06-22 19:49:51', '2026-08-22 15:20:09'),
(34, 3, 3, 1.00, '2026-06-22', NULL, '2026-06-22 19:51:27', '2026-06-25 00:11:51'),
(37, 2, 3, 1.00, '2026-06-22', NULL, '2026-06-22 20:04:53', '2026-09-07 22:29:13'),
(38, 3, 1, 1.00, '2026-06-25', NULL, '2026-06-25 14:56:00', '2026-09-01 17:29:36'),
(39, 2, 1, 2.00, '2026-08-22', NULL, '2026-08-22 15:31:54', '2026-09-08 20:26:41'),
(40, 2, 2, 1.00, '2026-08-22', NULL, '2026-08-22 15:32:55', '2026-09-07 22:42:26');

-- --------------------------------------------------------

--
-- Table structure for table `prescription_schedules`
--

CREATE TABLE `prescription_schedules` (
  `schedule_id` int(11) NOT NULL,
  `prescription_id` int(11) NOT NULL,
  `dispense_time` time NOT NULL,
  `day_of_week` tinyint(4) DEFAULT NULL COMMENT '1=Mon,2=Tue,...7=Sun, NULL=all days'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `prescription_schedules`
--

INSERT INTO `prescription_schedules` (`schedule_id`, `prescription_id`, `dispense_time`, `day_of_week`) VALUES
(92, 23, '17:22:00', NULL),
(108, 34, '12:14:00', NULL),
(113, 21, '14:55:00', NULL),
(299, 29, '17:29:00', 1),
(300, 29, '17:29:00', 2),
(301, 29, '17:29:00', 3),
(302, 29, '17:29:00', 4),
(303, 29, '17:29:00', 5),
(304, 29, '17:29:00', 6),
(305, 29, '17:29:00', 7),
(306, 29, '17:30:00', 1),
(307, 29, '17:30:00', 2),
(308, 29, '17:30:00', 3),
(309, 29, '17:30:00', 4),
(310, 29, '17:30:00', 5),
(311, 29, '17:30:00', 6),
(312, 29, '17:30:00', 7),
(313, 30, '17:02:00', 1),
(314, 30, '17:02:00', 2),
(315, 30, '17:02:00', 3),
(316, 30, '17:02:00', 4),
(317, 30, '17:02:00', 5),
(318, 30, '17:02:00', 6),
(319, 30, '17:02:00', 7),
(320, 30, '18:03:00', 1),
(321, 30, '18:03:00', 2),
(322, 30, '18:03:00', 3),
(323, 30, '18:03:00', 4),
(324, 30, '18:03:00', 5),
(325, 30, '18:03:00', 6),
(326, 30, '18:03:00', 7),
(350, 38, '00:46:00', NULL),
(358, 37, '08:00:00', 1),
(359, 37, '08:00:00', 2),
(360, 37, '08:00:00', 3),
(361, 37, '08:00:00', 4),
(362, 37, '08:00:00', 5),
(363, 37, '08:00:00', 6),
(364, 37, '08:00:00', 7),
(386, 40, '15:37:00', 1),
(387, 40, '15:37:00', 2),
(388, 40, '15:37:00', 3),
(389, 40, '15:37:00', 4),
(390, 40, '15:37:00', 5),
(391, 40, '15:37:00', 6),
(392, 40, '15:37:00', 7),
(393, 40, '15:37:00', 1),
(394, 40, '15:37:00', 2),
(395, 40, '15:37:00', 3),
(396, 40, '15:37:00', 4),
(397, 40, '15:37:00', 5),
(398, 40, '15:37:00', 6),
(399, 40, '15:37:00', 7),
(423, 39, '20:28:00', 1),
(424, 39, '20:28:00', 2),
(425, 39, '20:28:00', 3),
(426, 39, '20:28:00', 4),
(427, 39, '20:28:00', 5),
(428, 39, '20:28:00', 6),
(429, 39, '20:28:00', 7);

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
(1, 'caregiver1@example.com', '123456', 'caregiver', 'OOI XIEN XIEN', '+60197560221', 'johor', 'Female', '1980-03-21', '/static/profiles/caregiver_1_1_1_Sasuke023.png', 1, '2026-04-17 00:29:27', '2026-09-08 20:24:53'),
(2, 'ahmad125@gmail.com', '123456', 'patient', 'Ahmad Abdullah', '+60110000001', 'No 1, Jalan SS2, jalan keris 28', 'Male', '1945-05-15', 'https://randomuser.me/api/portraits/men/1.jpg', 1, '2026-04-17 00:29:27', '2026-09-07 22:16:31'),
(3, 'patient2@example.com', '123456', 'patient', 'Mei Ling Tan', '+60110000002', '22, Lorong Gombak, KL', 'Female', '1948-07-20', '/static/profiles/patient_3_scaled_1000020585.jpg', 1, '2026-04-17 00:29:27', '2026-06-23 19:57:13'),
(4, 'ooi14@gmail.com', '123456', 'patient', 'irynooi', '+60197560221', '2,jalan keris 28,Taman puteri wangsa', 'Female', '1979-03-20', NULL, 1, '2026-05-06 16:10:38', '2026-08-22 17:08:34'),
(16, 'testing12@gmail.com', '123456', 'patient', 'hii', '+60197560221', 'johor', 'Female', '1996-06-16', NULL, 1, '2026-06-02 19:15:42', '2026-08-27 21:19:42'),
(18, 'testcg@gmail.com', '123456', 'caregiver', 'test_caregiver', '+60197560221', 'johor ', 'Male', '2006-06-20', NULL, 1, '2026-06-15 20:53:24', '2026-08-22 14:17:54'),
(19, 'test_patient@gmail.com', '123456', 'patient', 'test_patient', '+60197560221', 'johor', 'Male', '1996-06-07', NULL, 1, '2026-06-15 20:59:27', '2026-08-22 14:17:54'),
(23, 'cg@gmail.com', 'xxxxxx', 'caregiver', 'cg ', '+60197560221', 'johor ', 'Male', '2006-06-02', NULL, 1, '2026-06-21 14:41:37', '2026-08-22 14:17:54'),
(24, 'xienxien13@gmail.com', '123456', 'patient', 'ooi xienxien', '+60197560221', 'johor', 'Female', '1996-07-02', NULL, 1, '2026-06-25 14:47:46', '2026-08-22 14:17:54'),
(25, 'meiemi@gmail.cok', '123456', 'patient', 'meimei', '+60167854225', 'johor', 'Male', '1965-08-10', NULL, 1, '2026-07-26 19:35:46', '2026-08-22 14:17:54'),
(26, 'iruni@gmail.com', '123456', 'patient', 'iruni', '+601867534937', 'johor', 'Female', '1958-08-10', NULL, 1, '2026-07-26 19:37:28', '2026-08-22 14:17:54'),
(27, 'kayla@gmail.com', '123456', 'patient', 'kayla', '+60197560221', 'kedah', 'Female', '1961-08-10', NULL, 1, '2026-07-26 19:39:53', '2026-08-22 14:17:54'),
(28, 'yue@gmail.com', '123456', 'patient', 'wang yue', '+60197560221', 'johor', 'Male', '1966-07-13', NULL, 1, '2026-07-26 19:42:14', '2026-08-22 14:17:54'),
(29, 'ping@gmail.com', '123456', 'patient', 'ping ping', '+60197560221', 'kelantan', 'Male', '1955-08-10', NULL, 1, '2026-07-26 19:43:09', '2026-08-22 14:17:54');

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
-- Indexes for table `hardware_tickets`
--
ALTER TABLE `hardware_tickets`
  ADD PRIMARY KEY (`ticket_id`);

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
-- Indexes for table `prescription_schedules`
--
ALTER TABLE `prescription_schedules`
  ADD PRIMARY KEY (`schedule_id`),
  ADD KEY `fk_prescription_time` (`prescription_id`);

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
  MODIFY `adlog_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=251;

--
-- AUTO_INCREMENT for table `ai_adherence_prediction`
--
ALTER TABLE `ai_adherence_prediction`
  MODIFY `ad_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=442;

--
-- AUTO_INCREMENT for table `hardware_tickets`
--
ALTER TABLE `hardware_tickets`
  MODIFY `ticket_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `iot_device`
--
ALTER TABLE `iot_device`
  MODIFY `device_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `medications`
--
ALTER TABLE `medications`
  MODIFY `medication_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `notification_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=372;

--
-- AUTO_INCREMENT for table `patient_caregiver_mapping`
--
ALTER TABLE `patient_caregiver_mapping`
  MODIFY `mapping_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT for table `prescription_config`
--
ALTER TABLE `prescription_config`
  MODIFY `prescription_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=43;

--
-- AUTO_INCREMENT for table `prescription_schedules`
--
ALTER TABLE `prescription_schedules`
  MODIFY `schedule_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=430;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=30;

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

--
-- Constraints for table `prescription_schedules`
--
ALTER TABLE `prescription_schedules`
  ADD CONSTRAINT `fk_prescription_time` FOREIGN KEY (`prescription_id`) REFERENCES `prescription_config` (`prescription_id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
