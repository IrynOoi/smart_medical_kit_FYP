# notification_model.py - Database operations for in-app notifications and stock alerts

from db import get_db_connection
import time  # (unused, but kept for potential future use)

# Constants for stock alert types
STOCK_ALERT_TYPES = ('LOW_STOCK', 'OUT_OF_STOCK')


# ---------------------- Helper: Insert Notification Only If Missing ----------------------
def _insert_notification_if_missing(
    cursor,
    recipient_id,
    title,
    message,
    notif_type,
    unread_only=True,
    newer_than=None,
):
    """
    Insert a notification only if an identical one (same recipient, title, message, type)
    does not already exist, with optional filters:
      - unread_only: only consider unread notifications when checking duplicates
      - newer_than: only consider notifications created after this timestamp
    Returns True if a new row was inserted, False otherwise.
    """
    # Build parameters for the subquery checks
    params = [recipient_id, title, message, notif_type]
    unread_filter = 'AND is_read = 0' if unread_only else ''
    newer_filter = ''
    if newer_than is not None:
        newer_filter = 'AND created_at >= %s'
        params.append(newer_than)

    # Use a conditional INSERT: insert only if no matching row exists
    query = f'''
        INSERT INTO notifications (recipient_id, title, message, type, is_read, created_at)
        SELECT %s, %s, %s, %s, 0, NOW()
        FROM DUAL
        WHERE NOT EXISTS (
            SELECT 1
            FROM notifications
            WHERE recipient_id = %s
              AND title = %s
              AND message = %s
              AND type = %s
              {unread_filter}
              {newer_filter}
        )
    '''
    # The parameters for the SELECT part are repeated; build the tuple
    insert_params = [recipient_id, title, message, notif_type] + params
    cursor.execute(query, tuple(insert_params))
    return cursor.rowcount > 0


# ---------------------- Insert a General Notification ----------------------
def insert_notification(recipient_id, title, message, notif_type='REMINDER'):
    """
    Insert a new notification for a user (patient or caregiver).
    Uses the duplicate-avoiding helper.
    Returns True if inserted, False if duplicate existed.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        inserted = _insert_notification_if_missing(
            cursor, recipient_id, title, message, notif_type
        )
        conn.commit()
        cursor.close()
    return inserted


# ---------------------- Insert a Caregiver Notification (Alias) ----------------------
def insert_caregiver_notification(caregiver_id, title, message, notif_type='ALERT'):
    """
    Convenience wrapper for inserting caregiver notifications.
    """
    return insert_notification(caregiver_id, title, message, notif_type)


# ---------------------- Retrieve Patient Notifications ----------------------
def get_patient_notifications(patient_id):
    """
    Fetch the most recent 20 notifications for a patient.
    Returns a list of dicts with notification details.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT notification_id,
                   recipient_id,
                   recipient_id AS patient_id,   -- Alias for compatibility
                   title,
                   message,
                   type,
                   is_read,
                   created_at
            FROM notifications
            WHERE recipient_id = %s
            ORDER BY created_at DESC
            LIMIT 20
        ''', (patient_id,))
        notifications = cursor.fetchall()
        cursor.close()
    return notifications


# ---------------------- Retrieve Caregiver Notifications (with Stock Sync) ----------------------
def get_caregiver_notifications(caregiver_id, limit=50):
    """
    Fetch the most recent notifications for a caregiver.
    First syncs stock notifications to ensure they are up-to-date.
    Returns a list of dicts.
    """
    sync_caregiver_stock_notifications(caregiver_id)   # Refresh stock alerts before reading

    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT notification_id,
                   recipient_id,
                   title,
                   message,
                   type,
                   is_read,
                   created_at
            FROM notifications
            WHERE recipient_id = %s
            ORDER BY created_at DESC
            LIMIT %s
        ''', (caregiver_id, limit))
        notifications = cursor.fetchall()
        cursor.close()
    return notifications


# ---------------------- Helper: Aggregate Stock Alerts by Medication ----------------------
def _aggregate_stock_alerts_by_medication(rows):
    """
    Group a list of stock alert rows by (caregiver_id, medication_id).
    Computes the worst status (OUT_OF_STOCK > LOW_STOCK > OK) and aggregates patient names.
    Returns a list of aggregated dicts.
    """
    grouped = {}
    for row in rows:
        caregiver_id = row['caregiver_id']
        med_id = row['medication_id']
        key = (caregiver_id, med_id)
        if key not in grouped:
            grouped[key] = {
                'caregiver_id': caregiver_id,
                'medication_id': med_id,
                'medication_name': row['medication_name'],
                'patients': [],
                'worst_status': 'OK',
                'current_inventory': row['current_inventory'],
                'refill_threshold': row['refill_threshold'],
                'updated_at': row.get('updated_at'),
            }
        # Append patient info to this medication group
        grouped[key]['patients'].append({
            'patient_name': row['patient_name'],
            'stock_status': row['stock_status'],
        })
        # Update worst status: OUT_OF_STOCK overrides LOW_STOCK overrides OK
        if row['stock_status'] == 'OUT_OF_STOCK':
            grouped[key]['worst_status'] = 'OUT_OF_STOCK'
        elif row['stock_status'] == 'LOW_STOCK' and grouped[key]['worst_status'] != 'OUT_OF_STOCK':
            grouped[key]['worst_status'] = 'LOW_STOCK'
        # Keep the lowest inventory across patients (optional)
        if row['current_inventory'] < grouped[key]['current_inventory']:
            grouped[key]['current_inventory'] = row['current_inventory']
    return list(grouped.values())


# ---------------------- Mark a Notification as Read ----------------------
def mark_notification_as_read(notification_id):
    """
    Set is_read = 1 for a specific notification by its ID.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            'UPDATE notifications SET is_read = 1 WHERE notification_id = %s',
            (notification_id,)
        )
        conn.commit()
        cursor.close()


# ---------------------- Mark All Reminders as Read for a Patient ----------------------
def mark_all_reminders_read(patient_id):
    """
    Mark all unread REMINDER notifications for a patient as read.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE notifications
            SET is_read = 1
            WHERE recipient_id = %s AND type = 'REMINDER' AND is_read = 0
        ''', (patient_id,))
        conn.commit()
        cursor.close()


# ---------------------- Mark Reminders for a Specific Medication as Read ----------------------
def mark_single_reminder_read(patient_id, medication_name):
    """
    Mark all unread REMINDER notifications that contain the given medication name
    in their message as read.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        search_term = f"%{medication_name}%"   # Wildcard search in message
        cursor.execute('''
            UPDATE notifications
            SET is_read = 1
            WHERE recipient_id = %s
              AND type = 'REMINDER'
              AND is_read = 0
              AND message LIKE %s
        ''', (patient_id, search_term))
        conn.commit()
        cursor.close()


# ---------------------- Get Stock Alert Rows (Raw, for Caregiver) ----------------------
def get_caregiver_stock_alert_rows(caregiver_id):
    """
    Fetch raw stock alert rows for a caregiver, combining both prescription-linked
    and device-level medications. Returns only rows with stock_status != 'OK'.
    Results are sorted by inventory (lowest first) and then by names.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        # Get rows from prescriptions (patients) with non-OK status
        rows = [
            row for row in _fetch_stock_rows(cursor, caregiver_id=caregiver_id)
            if row['stock_status'] != 'OK'
        ]
        # Add rows from devices that are not linked to any prescription for this caregiver
        rows.extend(_fetch_device_stock_rows(cursor, caregiver_id=caregiver_id, low_only=True))
        # Sort: lowest inventory first, then by medication name, then patient name
        rows.sort(key=lambda row: (
            row['current_inventory'] or 0,
            row['medication_name'] or '',
            row['patient_name'] or '',
        ))
        cursor.close()
    return rows


# ---------------------- Get Formatted Stock Notifications for Caregiver ----------------------
def get_caregiver_stock_notification_rows(caregiver_id):
    """
    Fetch aggregated stock notifications for a caregiver, creating or updating
    notification records in the notifications table as needed.
    Returns a list of notification-like objects with stock details.
    """
    # Ensure stock notifications are up-to-date
    sync_caregiver_stock_notifications(caregiver_id)

    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)

        # Fetch all non-OK stock rows from both prescription and device sources
        rows = [
            row for row in _fetch_stock_rows(cursor, caregiver_id=caregiver_id)
            if row['stock_status'] != 'OK'
        ]
        rows.extend(_fetch_device_stock_rows(cursor, caregiver_id=caregiver_id, low_only=True))

        # Aggregate by medication
        aggregated = _aggregate_stock_alerts_by_medication(rows)

        notifications = []
        for agg in aggregated:
            # Build title and message based on worst status and list of patients
            med_name = agg['medication_name']
            patient_names = [p['patient_name'] for p in agg['patients']]
            patient_list = ", ".join(patient_names)
            if agg['worst_status'] == 'OUT_OF_STOCK':
                title = 'Medicine Out of Stock'
                message = f'{med_name} is out of stock for: {patient_list}. Please restock immediately.'
                notif_type = 'OUT_OF_STOCK'
            else:  # LOW_STOCK
                title = 'Medicine Low Stock'
                message = f'{med_name} is running low for: {patient_list}. Please restock soon.'
                notif_type = 'LOW_STOCK'

            # Check if there is already an unread notification for this caregiver+medication
            cursor.execute('''
                SELECT notification_id, is_read
                FROM notifications
                WHERE recipient_id = %s
                  AND title = %s
                  AND message = %s
                  AND type = %s
                  AND is_read = 0
                ORDER BY created_at DESC
                LIMIT 1
            ''', (caregiver_id, title, message, notif_type))
            existing = cursor.fetchone()

            if existing:
                # Use the existing notification details
                notif = existing
                notif.update({
                    'recipient_id': caregiver_id,
                    'title': title,
                    'message': message,
                    'type': notif_type,
                })
            else:
                # Create a placeholder for a new notification (not yet inserted)
                notif = {
                    'notification_id': None,
                    'recipient_id': caregiver_id,
                    'title': title,
                    'message': message,
                    'type': notif_type,
                    'is_read': 0,
                    'created_at': None,
                }

            # Combine aggregation data with notification data
            item = dict(agg)
            item.update(notif)
            notifications.append(item)

        # Sort: unread first, then out-of-stock before low-stock
        notifications.sort(key=lambda row: (
            row['is_read'] or 0,
            0 if row['worst_status'] == 'OUT_OF_STOCK' else 1,
        ))
        cursor.close()
    return notifications


# ---------------------- Internal: Fetch Stock Rows from Prescriptions ----------------------
def _fetch_stock_rows(cursor, caregiver_id=None, patient_id=None, medication_id=None, prescription_id=None):
    """
    Fetch stock information for medications linked to patients via prescriptions.
    Returns rows with medication details, patient info, and computed stock_status.
    Filters can be applied by caregiver, patient, medication, or prescription.
    """
    conditions = [
        'u.is_active = TRUE',
        '(pc.end_date IS NULL OR pc.end_date >= CURDATE())',
    ]
    params = []

    # Build WHERE clause based on provided filters
    if caregiver_id is not None:
        conditions.append('pcm.caregiver_id = %s')
        params.append(caregiver_id)
    if patient_id is not None:
        conditions.append('p.patient_id = %s')
        params.append(patient_id)
    if medication_id is not None:
        conditions.append('m.medication_id = %s')
        params.append(medication_id)
    if prescription_id is not None:
        conditions.append('pc.prescription_id = %s')
        params.append(prescription_id)

    where_clause = ' AND '.join(conditions)
    cursor.execute(f'''
        SELECT DISTINCT
            pc.prescription_id,
            p.patient_id,
            pcm.caregiver_id,                     -- from patient_caregiver_mapping
            u.full_name AS patient_name,
            m.medication_id,
            m.medication_name,
            m.current_inventory,
            m.refill_threshold,
            m.updated_at,
            m.device_id,
            d.device_serial,
            CASE
                WHEN m.current_inventory <= 0 THEN 'OUT_OF_STOCK'
                WHEN m.current_inventory <= m.refill_threshold THEN 'LOW_STOCK'
                ELSE 'OK'
            END AS stock_status
        FROM patient p
        JOIN users u ON p.patient_id = u.user_id
        JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id   -- mapping table
        JOIN prescription_config pc ON p.patient_id = pc.patient_id
        JOIN medications m ON pc.medication_id = m.medication_id
        LEFT JOIN iot_device d ON m.device_id = d.device_id
        WHERE {where_clause}
    ''', tuple(params))
    return cursor.fetchall()


# ---------------------- Internal: Fetch Stock Rows from Devices (Unlinked to Patient) ----------------------
def _fetch_device_stock_rows(cursor, caregiver_id=None, medication_id=None, low_only=False):
    """
    Fetch stock rows for medications that are assigned to a device but NOT linked to any
    active prescription for the given caregiver. This catches devices that may have stock
    but are not yet associated with a patient prescription.
    """
    sub_conditions = [
        'u.is_active = TRUE',
        '(pc.end_date IS NULL OR pc.end_date >= CURDATE())',
        'med.device_id IS NOT NULL',
    ]
    outer_conditions = ['m.device_id IS NOT NULL']
    params = []

    if caregiver_id is not None:
        sub_conditions.append('pcm.caregiver_id = %s')
        params.append(caregiver_id)
    if medication_id is not None:
        outer_conditions.append('m.medication_id = %s')
        params.append(medication_id)
    if low_only:
        outer_conditions.append('m.current_inventory <= m.refill_threshold')

    sub_where = ' AND '.join(sub_conditions)
    outer_where = ' AND '.join(outer_conditions)

    cursor.execute(f'''
        SELECT DISTINCT
            NULL AS prescription_id,
            NULL AS patient_id,
            dc.caregiver_id,
            CONCAT('Device ', d.device_serial) AS patient_name,   -- Fake patient name for device
            m.medication_id,
            m.medication_name,
            m.current_inventory,
            m.refill_threshold,
            m.updated_at,
            m.device_id,
            d.device_serial,
            CASE
                WHEN m.current_inventory <= 0 THEN 'OUT_OF_STOCK'
                WHEN m.current_inventory <= m.refill_threshold THEN 'LOW_STOCK'
                ELSE 'OK'
            END AS stock_status
        FROM medications m
        JOIN iot_device d ON m.device_id = d.device_id
        JOIN (
            -- Subquery: get distinct (caregiver_id, device_id) from active prescriptions
            SELECT DISTINCT pcm.caregiver_id, med.device_id
            FROM patient p
            JOIN users u ON p.patient_id = u.user_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            JOIN prescription_config pc ON p.patient_id = pc.patient_id
            JOIN medications med ON pc.medication_id = med.medication_id
            WHERE {sub_where}
        ) dc ON dc.device_id = m.device_id
        WHERE {outer_where}
          -- Exclude medications that ARE linked to an active prescription for this caregiver
          AND NOT EXISTS (
              SELECT 1
              FROM prescription_config pc2
              JOIN patient p2 ON pc2.patient_id = p2.patient_id
              JOIN patient_caregiver_mapping pcm2 ON p2.patient_id = pcm2.patient_id
              WHERE pc2.medication_id = m.medication_id
                AND pcm2.caregiver_id = dc.caregiver_id
                AND (pc2.end_date IS NULL OR pc2.end_date >= CURDATE())
          )
    ''', tuple(params))
    return cursor.fetchall()


# ---------------------- Helper: Generate Notification Content from a Stock Row ----------------------
def _stock_notification_content(row):
    """
    Generate title, message, and type based on a stock row.
    Used internally for constructing notifications.
    """
    medication_name = row['medication_name']
    patient_name = row['patient_name']
    location = f'for {patient_name}' if row.get('patient_id') else f'on {patient_name}'
    if row['stock_status'] == 'OUT_OF_STOCK':
        return (
            'Medicine Out of Stock',
            f'{medication_name} {location} is out of stock. Please restock immediately.',
            'OUT_OF_STOCK',
        )
    # LOW_STOCK
    return (
        'Medicine Low Stock',
        f'{medication_name} {location} is running low. Please restock soon.',
        'LOW_STOCK',
    )


# ---------------------- Helper: Mark Related Stock Alerts as Read ----------------------
def _mark_related_stock_alerts_read(cursor, caregiver_id, medication_name, except_type=None):
    """
    Mark all unread stock alerts (LOW_STOCK/OUT_OF_STOCK) for a specific caregiver
    and medication as read, optionally excluding a specific type.
    Used when stock is restored to OK status.
    """
    params = [caregiver_id, f'%{medication_name}%', f'%{medication_name}%']
    type_filter = ''
    if except_type is not None:
        type_filter = 'AND type <> %s'
        params.append(except_type)

    cursor.execute(f'''
        UPDATE notifications
        SET is_read = 1
        WHERE recipient_id = %s
          AND type IN ('LOW_STOCK', 'OUT_OF_STOCK')
          AND is_read = 0
          AND message LIKE %s
          AND message LIKE %s
          {type_filter}
    ''', tuple(params))


# ---------------------- (Commented-out) Advisory Lock Functions ----------------------
# def _acquire_lock(cursor, lock_name, timeout=5):
#     """Acquire MySQL advisory lock. Returns True if acquired."""
#     conn = cursor.connection
#     with conn.cursor() as lock_cursor:
#         lock_cursor.execute("SELECT GET_LOCK(%s, %s)", (lock_name, timeout))
#         result = lock_cursor.fetchone()
#         return result[0] == 1

# def _release_lock(cursor, lock_name):
#     conn = cursor.connection
#     with conn.cursor() as lock_cursor:
#         lock_cursor.execute("SELECT RELEASE_LOCK(%s)", (lock_name,))


# ---------------------- Core: Synchronize Stock Notifications ----------------------
def sync_stock_notifications(caregiver_id=None, patient_id=None, medication_id=None, prescription_id=None):
    """
    Main function to sync stock alert notifications for a caregiver, patient, or specific medication.
    - Fetches current stock status for affected medications.
    - Creates or updates notifications for medications that are LOW_STOCK or OUT_OF_STOCK.
    - Marks notifications as read when stock is OK.
    Returns the number of new notifications created.
    """
    if caregiver_id is None and patient_id is None and medication_id is None and prescription_id is None:
        return 0   # No filters provided, do nothing

    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)

        # Fetch stock rows based on filters
        rows = _fetch_stock_rows(
            cursor,
            caregiver_id=caregiver_id,
            patient_id=patient_id,
            medication_id=medication_id,
            prescription_id=prescription_id,
        )
        # Include device rows only if not filtering by a specific patient or prescription
        if patient_id is None and prescription_id is None:
            rows.extend(_fetch_device_stock_rows(
                cursor,
                caregiver_id=caregiver_id,
                medication_id=medication_id,
            ))

        # Aggregate by medication
        aggregated = _aggregate_stock_alerts_by_medication(rows)

        # ── Dedup: keep only ONE aggregated entry per (caregiver_id, medication_id).
        # _fetch_stock_rows and _fetch_device_stock_rows can both return rows for
        # the same medication, producing two separate aggregated items and therefore
        # two duplicate notification INSERTs.  We merge them here before touching the DB.
        seen_keys: set = set()
        deduped_aggregated = []
        for agg in aggregated:
            key = (agg['caregiver_id'], agg['medication_id'])
            if key in seen_keys:
                continue
            seen_keys.add(key)
            deduped_aggregated.append(agg)

        created = 0

        for agg in deduped_aggregated:
            caregiver = agg['caregiver_id']
            if caregiver is None:
                continue   # Should not happen

            # Build patient list string
            patient_names = [p['patient_name'] for p in agg['patients']]
            patient_list = ", ".join(patient_names)

            # Determine title, message, and type based on worst status
            if agg['worst_status'] == 'OUT_OF_STOCK':
                title = 'Medicine Out of Stock'
                message = f'{agg["medication_name"]} is out of stock for: {patient_list}. Please restock immediately.'
                notif_type = 'OUT_OF_STOCK'
            elif agg['worst_status'] == 'LOW_STOCK':
                title = 'Medicine Low Stock'
                message = f'{agg["medication_name"]} is running low for: {patient_list}. Please restock soon.'
                notif_type = 'LOW_STOCK'
            else:
                # Stock is OK: mark any existing unread alerts for this medication as read
                _mark_related_stock_alerts_read(cursor, caregiver, agg['medication_name'], agg['medication_name'])
                continue

            # Fetch ALL unread stock notifications for this medication name.
            # If more than one exists (leftover duplicates from prior runs), we
            # update the first one and delete the rest to self-heal the DB.
            cursor.execute('''
                SELECT notification_id, type
                FROM notifications
                WHERE recipient_id = %s
                  AND type IN ('LOW_STOCK', 'OUT_OF_STOCK')
                  AND is_read = 0
                  AND message LIKE %s
                ORDER BY created_at ASC
            ''', (caregiver, f'%{agg["medication_name"]}%'))
            existing_rows = cursor.fetchall()

            if existing_rows:
                # Keep the oldest unread notification; mark any extras as read
                primary = existing_rows[0]
                for duplicate in existing_rows[1:]:
                    cursor.execute(
                        'UPDATE notifications SET is_read = 1 WHERE notification_id = %s',
                        (duplicate['notification_id'],)
                    )

                # Update the surviving notification with the latest message/type
                if primary['type'] != notif_type:
                    # Type changed (e.g., from LOW_STOCK to OUT_OF_STOCK)
                    cursor.execute('''
                        UPDATE notifications
                        SET title = %s, message = %s, type = %s, created_at = NOW()
                        WHERE notification_id = %s
                    ''', (title, message, notif_type, primary['notification_id']))
                else:
                    # Same type: just refresh message and timestamp
                    cursor.execute('''
                        UPDATE notifications
                        SET message = %s, created_at = NOW()
                        WHERE notification_id = %s
                    ''', (message, primary['notification_id']))
            else:
                # No existing unread notification: insert a new one
                cursor.execute('''
                    INSERT INTO notifications (recipient_id, title, message, type, is_read, created_at)
                    VALUES (%s, %s, %s, %s, 0, NOW())
                ''', (caregiver, title, message, notif_type))
                created += 1

        conn.commit()
        cursor.close()
    return created


# ---------------------- Wrappers for Specific Sync Scenarios ----------------------
def sync_caregiver_stock_notifications(caregiver_id):
    """
    Sync stock notifications for a single caregiver.
    """
    return sync_stock_notifications(caregiver_id=caregiver_id)


def sync_patient_caregiver_stock_notifications(patient_id):
    """
    Sync stock notifications for all caregivers of a given patient.
    (By passing patient_id, it will fetch the associated caregiver(s) through the mapping.)
    """
    return sync_stock_notifications(patient_id=patient_id)


def sync_prescription_stock_notifications(prescription_id):
    """
    Sync stock notifications for a specific prescription (affects its patient's caregivers).
    """
    return sync_stock_notifications(prescription_id=prescription_id)


def sync_medication_stock_notifications(medication_id):
    """
    Sync stock notifications for a specific medication (affects all caregivers linked to it).
    """
    return sync_stock_notifications(medication_id=medication_id)