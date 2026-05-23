-- Allow the notifications table to store notifications for patients and caregivers.
-- Run once in phpMyAdmin before using caregiver stock notifications.

ALTER TABLE `notifications`
  DROP FOREIGN KEY `notifications_ibfk_1`;

ALTER TABLE `notifications`
  ADD CONSTRAINT `notifications_ibfk_1`
  FOREIGN KEY (`recipient_id`) REFERENCES `users` (`user_id`)
  ON DELETE CASCADE;
