-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: May 23, 2026 at 09:09 PM
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
(36, 2, 1, '2026-05-23 13:43:00', NULL, 'MISSED', '2026-05-23 13:43:00');

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
(1, 2, 76.60, 'LOW', '2026-05-12 15:16:17', '{\"age\": 81, \"day\": \"Tuesday\", \"time\": \"Afternoon\", \"recent_adherence\": [1.0, 1.0, 1.0], \"temporal_pattern\": \"Pattern extracted from LSTM\"}'),
(2, 3, 67.21, 'MEDIUM', '2026-05-12 15:16:17', '{\"age\": 77, \"day\": \"Tuesday\", \"time\": \"Afternoon\", \"recent_adherence\": [1.0, 0.0, 1.0], \"temporal_pattern\": \"Pattern extracted from LSTM\"}'),
(7, 4, 58.59, 'MEDIUM', '2026-05-12 15:16:17', '{\"age\": 47, \"day\": \"Tuesday\", \"time\": \"Afternoon\", \"recent_adherence\": [1.0, 1.0, 1.0], \"temporal_pattern\": \"Pattern extracted from LSTM\"}');

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
(1);

-- --------------------------------------------------------

--
-- Stand-in structure for view `inventory_status`
-- (See below for the actual view)
--
CREATE TABLE `inventory_status` (
`prescription_id` int(11)
,`patient_id` int(11)
,`patient_name` varchar(100)
,`medication_name` varchar(100)
,`current_inventory` int(11)
,`refill_threshold` int(11)
,`stock_status` varchar(3)
);

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
(1, 'DISP-1', 100, '192.168.0.12', '2026-05-23 21:08:45', -59);

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
(1, 'Aspirin', 13, 10, 1, 1, '2026-05-05 15:33:23', '2026-05-20 08:47:33'),
(2, 'Lisinopril', 2, 5, 1, 3, '2026-05-05 15:33:23', '2026-05-23 17:55:07'),
(3, 'Metformin', 0, 10, 1, 2, '2026-05-05 15:33:23', '2026-05-23 20:07:07');

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `notification_id` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` mediumtext NOT NULL,
  `type` varchar(50) DEFAULT 'REMINDER',
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `notifications`
--

INSERT INTO `notifications` (`notification_id`, `patient_id`, `title`, `message`, `type`, `is_read`, `created_at`) VALUES
(29, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin.', 'REMINDER', 1, '2026-05-15 16:52:14'),
(30, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin.', 'REMINDER', 1, '2026-05-15 21:58:20'),
(48, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-05-20 13:53.', 'REMINDER', 1, '2026-05-20 13:50:12'),
(49, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-05-20 13:57.', 'REMINDER', 1, '2026-05-20 13:55:12'),
(50, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-05-20 15:27.', 'REMINDER', 1, '2026-05-20 15:22:46'),
(51, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-05-20 15:53.', 'REMINDER', 1, '2026-05-20 15:49:13'),
(52, 2, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin at 2026-05-20 21:57.', 'REMINDER', 0, '2026-05-20 21:47:12'),
(53, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-05-20 22:40.', 'REMINDER', 1, '2026-05-20 22:35:53'),
(54, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-05-20 11:46 PM.', 'REMINDER', 0, '2026-05-20 23:41:54'),
(55, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Aspirin at 2026-05-23 11:53 AM.', 'REMINDER', 0, '2026-05-23 11:43:58'),
(56, 3, 'Medication Reminder', 'Time to take 1 tablet(s) of Metformin at 2026-05-23 01:43 PM.', 'REMINDER', 0, '2026-05-23 13:39:58');

-- --------------------------------------------------------

--
-- Table structure for table `patient`
--

CREATE TABLE `patient` (
  `patient_id` int(11) NOT NULL,
  `caregiver_id` int(11) DEFAULT NULL,
  `medical_notes` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `patient`
--

INSERT INTO `patient` (`patient_id`, `caregiver_id`, `medical_notes`) VALUES
(2, 1, NULL),
(3, 1, 'Type 2 diabetes, requires insulin monitoring.'),
(4, 1, NULL);

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
(2, 3, 3, 1.00, '43 13 * * *', '2026-05-05', NULL, '2026-05-05 22:31:02', '2026-05-23 13:39:00'),
(8, 2, 1, 1.00, '57 21 * * 2,3,4', '2026-05-14', NULL, '2026-05-14 21:49:17', '2026-05-20 11:48:27'),
(9, 3, 1, 1.00, '53 11 * * *', '2026-05-14', NULL, '2026-05-14 22:57:29', '2026-05-20 11:48:56');

-- --------------------------------------------------------

--
-- Stand-in structure for view `prescription_details`
-- (See below for the actual view)
--
CREATE TABLE `prescription_details` (
`prescription_id` int(11)
,`patient_id` int(11)
,`medication_name` varchar(100)
,`dosage_tablet` decimal(10,2)
,`dispense_schedule` varchar(50)
,`current_inventory` int(11)
,`refill_threshold` int(11)
,`start_date` date
,`end_date` date
,`device_id` int(11)
,`motor_slot` int(11)
,`created_at` datetime
,`updated_at` datetime
);

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
(2, 'ahmad125@gmail.com', 'hash2', 'patient', 'Ahmad Abdullah', '+60110000001', 'No 1, Jalan SS2, jalan keris 28', 'Male', '1945-05-15', 'https://randomuser.me/api/portraits/men/1.jpg', 1, '2026-04-17 00:29:27', '2026-05-20 22:02:44'),
(3, 'patient2@example.com', '123456', 'patient', 'Mei Ling Tan', '+60110000002', '22, Lorong Gombak, KL', 'Female', '1948-07-20', '/static/profiles/patient_3_scaled_1000020585.jpg', 1, '2026-04-17 00:29:27', '2026-04-27 08:43:49'),
(4, 'ooi14@gmail.com', '123456', 'patient', 'irynooi', '0197560221', '2,jalan keris 28,Taman puteri wangsa', 'Female', '1979-03-20', NULL, 1, '2026-05-06 16:10:38', '2026-05-08 19:39:20');

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
  ADD KEY `patient_id` (`patient_id`);

--
-- Indexes for table `patient`
--
ALTER TABLE `patient`
  ADD PRIMARY KEY (`patient_id`),
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
  MODIFY `adlog_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=37;

--
-- AUTO_INCREMENT for table `ai_adherence_prediction`
--
ALTER TABLE `ai_adherence_prediction`
  MODIFY `ad_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `iot_device`
--
ALTER TABLE `iot_device`
  MODIFY `device_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2257;

--
-- AUTO_INCREMENT for table `medications`
--
ALTER TABLE `medications`
  MODIFY `medication_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `notification_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=57;

--
-- AUTO_INCREMENT for table `prescription_config`
--
ALTER TABLE `prescription_config`
  MODIFY `prescription_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

-- --------------------------------------------------------

--
-- Structure for view `inventory_status`
--
DROP TABLE IF EXISTS `inventory_status`;

CREATE ALGORITHM=UNDEFINED DEFINER=`mytrusth`@`localhost` SQL SECURITY DEFINER VIEW `inventory_status`  AS SELECT `pc`.`prescription_id` AS `prescription_id`, `pc`.`patient_id` AS `patient_id`, `u`.`full_name` AS `patient_name`, `m`.`medication_name` AS `medication_name`, `m`.`current_inventory` AS `current_inventory`, `m`.`refill_threshold` AS `refill_threshold`, if(`m`.`current_inventory` <= `m`.`refill_threshold`,'LOW','OK') AS `stock_status` FROM (((`prescription_config` `pc` join `medications` `m` on(`pc`.`medication_id` = `m`.`medication_id`)) join `patient` `p` on(`pc`.`patient_id` = `p`.`patient_id`)) join `users` `u` on(`p`.`patient_id` = `u`.`user_id`)) ;

-- --------------------------------------------------------

--
-- Structure for view `prescription_details`
--
DROP TABLE IF EXISTS `prescription_details`;

CREATE ALGORITHM=UNDEFINED DEFINER=`mytrusth`@`localhost` SQL SECURITY DEFINER VIEW `prescription_details`  AS SELECT `pc`.`prescription_id` AS `prescription_id`, `pc`.`patient_id` AS `patient_id`, `m`.`medication_name` AS `medication_name`, `pc`.`dosage_tablet` AS `dosage_tablet`, `pc`.`dispense_schedule` AS `dispense_schedule`, `m`.`current_inventory` AS `current_inventory`, `m`.`refill_threshold` AS `refill_threshold`, `pc`.`start_date` AS `start_date`, `pc`.`end_date` AS `end_date`, `m`.`device_id` AS `device_id`, `m`.`motor_slot` AS `motor_slot`, `pc`.`created_at` AS `created_at`, `pc`.`updated_at` AS `updated_at` FROM (`prescription_config` `pc` join `medications` `m` on(`pc`.`medication_id` = `m`.`medication_id`)) ;

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
  ADD CONSTRAINT `medications_ibfk_1` FOREIGN KEY (`device_id`) REFERENCES `iot_device` (`device_id`) ON DELETE SET NULL;

--
-- Constraints for table `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `patient` (`patient_id`) ON DELETE CASCADE;

--
-- Constraints for table `patient`
--
ALTER TABLE `patient`
  ADD CONSTRAINT `patient_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `patient_ibfk_2` FOREIGN KEY (`caregiver_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

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
