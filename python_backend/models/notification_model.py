# notification_model.py
from db import get_db_connection
import time
STOCK_ALERT_TYPES = ('LOW_STOCK', 'OUT_OF_STOCK')


def _insert_notification_if_missing(
    cursor,
    recipient_id,
    title,
    message,
    notif_type,
    unread_only=True,
    newer_than=None,
):
    params = [recipient_id, title, message, notif_type]
    unread_filter = 'AND is_read = 0' if unread_only else ''
    newer_filter = ''
    if newer_than is not None:
        newer_filter = 'AND created_at >= %s'
        params.append(newer_than)

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
    insert_params = [recipient_id, title, message, notif_type] + params

    cursor.execute(query, tuple(insert_params))
    return cursor.rowcount > 0


def insert_notification(recipient_id, title, message, notif_type='REMINDER'):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        inserted = _insert_notification_if_missing(
            cursor, recipient_id, title, message, notif_type
        )
        conn.commit()
        cursor.close()
    return inserted


def insert_caregiver_notification(caregiver_id, title, message, notif_type='ALERT'):
    return insert_notification(caregiver_id, title, message, notif_type)


def get_patient_notifications(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT notification_id,
                   recipient_id,
                   recipient_id AS patient_id,
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


def get_caregiver_notifications(caregiver_id, limit=50):
    sync_caregiver_stock_notifications(caregiver_id)

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


def _aggregate_stock_alerts_by_medication(rows):
    """Group rows by (caregiver_id, medication_id) and compute worst status."""
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
        # Add patient info
        grouped[key]['patients'].append({
            'patient_name': row['patient_name'],
            'stock_status': row['stock_status'],
        })
        # Update worst status
        if row['stock_status'] == 'OUT_OF_STOCK':
            grouped[key]['worst_status'] = 'OUT_OF_STOCK'
        elif row['stock_status'] == 'LOW_STOCK' and grouped[key]['worst_status'] != 'OUT_OF_STOCK':
            grouped[key]['worst_status'] = 'LOW_STOCK'
        # Keep the lowest inventory across patients (optional)
        if row['current_inventory'] < grouped[key]['current_inventory']:
            grouped[key]['current_inventory'] = row['current_inventory']
    return list(grouped.values())


def mark_notification_as_read(notification_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            'UPDATE notifications SET is_read = 1 WHERE notification_id = %s',
            (notification_id,)
        )
        conn.commit()
        cursor.close()


def mark_all_reminders_read(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE notifications
            SET is_read = 1
            WHERE recipient_id = %s AND type = 'REMINDER' AND is_read = 0
        ''', (patient_id,))
        conn.commit()
        cursor.close()


def mark_single_reminder_read(patient_id, medication_name):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        search_term = f"%{medication_name}%"
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


def get_caregiver_stock_alert_rows(caregiver_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        rows = [
            row for row in _fetch_stock_rows(cursor, caregiver_id=caregiver_id)
            if row['stock_status'] != 'OK'
        ]
        rows.extend(_fetch_device_stock_rows(cursor, caregiver_id=caregiver_id, low_only=True))
        rows.sort(key=lambda row: (
            row['current_inventory'] or 0,
            row['medication_name'] or '',
            row['patient_name'] or '',
        ))
        cursor.close()
    return rows


def get_caregiver_stock_notification_rows(caregiver_id):
    sync_caregiver_stock_notifications(caregiver_id)

    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
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
            else:
                title = 'Medicine Low Stock'
                message = f'{med_name} is running low for: {patient_list}. Please restock soon.'
                notif_type = 'LOW_STOCK'

            # Check existing notification (unread) for this caregiver+medication
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
                notif = existing
                notif.update({
                    'recipient_id': caregiver_id,
                    'title': title,
                    'message': message,
                    'type': notif_type,
                })
            else:
                notif = {
                    'notification_id': None,
                    'recipient_id': caregiver_id,
                    'title': title,
                    'message': message,
                    'type': notif_type,
                    'is_read': 0,
                    'created_at': None,
                }

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


def _fetch_stock_rows(cursor, caregiver_id=None, patient_id=None, medication_id=None, prescription_id=None):
    conditions = [
        'u.is_active = TRUE',
        '(pc.end_date IS NULL OR pc.end_date >= CURDATE())',
    ]
    params = []

    # Build the join and filter based on the mapping table
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
            pcm.caregiver_id,                     -- use mapping table
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
        JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id   -- added
        JOIN prescription_config pc ON p.patient_id = pc.patient_id
        JOIN medications m ON pc.medication_id = m.medication_id
        LEFT JOIN iot_device d ON m.device_id = d.device_id
        WHERE {where_clause}
    ''', tuple(params))
    return cursor.fetchall()


def _fetch_device_stock_rows(cursor, caregiver_id=None, medication_id=None, low_only=False):
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
            CONCAT('Device ', d.device_serial) AS patient_name,
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
            SELECT DISTINCT pcm.caregiver_id, med.device_id
            FROM patient p
            JOIN users u ON p.patient_id = u.user_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id   -- added
            JOIN prescription_config pc ON p.patient_id = pc.patient_id
            JOIN medications med ON pc.medication_id = med.medication_id
            WHERE {sub_where}
        ) dc ON dc.device_id = m.device_id
        WHERE {outer_where}
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


def _stock_notification_content(row):
    medication_name = row['medication_name']
    patient_name = row['patient_name']
    location = f'for {patient_name}' if row.get('patient_id') else f'on {patient_name}'
    if row['stock_status'] == 'OUT_OF_STOCK':
        return (
            'Medicine Out of Stock',
            f'{medication_name} {location} is out of stock. Please restock immediately.',
            'OUT_OF_STOCK',
        )

    return (
        'Medicine Low Stock',
        f'{medication_name} {location} is running low. Please restock soon.',
        'LOW_STOCK',
    )


def _mark_related_stock_alerts_read(cursor, caregiver_id, medication_name, except_type=None):
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




# def _acquire_lock(cursor, lock_name, timeout=5):
#     """Acquire MySQL advisory lock. Returns True if acquired."""
#     # Create a fresh cursor without dictionary=True
#     conn = cursor.connection
#     with conn.cursor() as lock_cursor:
#         lock_cursor.execute("SELECT GET_LOCK(%s, %s)", (lock_name, timeout))
#         result = lock_cursor.fetchone()
#         return result[0] == 1   # Now result is a tuple, safe to index

# def _release_lock(cursor, lock_name):
#     conn = cursor.connection
#     with conn.cursor() as lock_cursor:
#         lock_cursor.execute("SELECT RELEASE_LOCK(%s)", (lock_name,))

def sync_stock_notifications(caregiver_id=None, patient_id=None, medication_id=None, prescription_id=None):
    """
    Synchronise stock alerts for a caregiver.
    """
    if caregiver_id is None and patient_id is None and medication_id is None and prescription_id is None:
        return 0

    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)

        rows = _fetch_stock_rows(
            cursor,
            caregiver_id=caregiver_id,
            patient_id=patient_id,
            medication_id=medication_id,
            prescription_id=prescription_id,
        )
        if patient_id is None and prescription_id is None:
            rows.extend(_fetch_device_stock_rows(
                cursor,
                caregiver_id=caregiver_id,
                medication_id=medication_id,
            ))

        aggregated = _aggregate_stock_alerts_by_medication(rows)
        created = 0

        for agg in aggregated:
            caregiver = agg['caregiver_id']
            if caregiver is None:
                continue

            # 1. 构建患者列表字符串
            patient_names = [p['patient_name'] for p in agg['patients']]
            patient_list = ", ".join(patient_names)

            if agg['worst_status'] == 'OUT_OF_STOCK':
                title = 'Medicine Out of Stock'
                message = f'{agg["medication_name"]} is out of stock for: {patient_list}. Please restock immediately.'
                notif_type = 'OUT_OF_STOCK'
            elif agg['worst_status'] == 'LOW_STOCK':
                title = 'Medicine Low Stock'
                message = f'{agg["medication_name"]} is running low for: {patient_list}. Please restock soon.'
                notif_type = 'LOW_STOCK'
            else:
                # 库存恢复正常：将该药物的所有未读库存警告标记为已读
                _mark_related_stock_alerts_read(cursor, caregiver, agg['medication_name'], agg['medication_name'])
                continue

            # 2. 检查是否已存在同一药物的未读库存通知
            cursor.execute('''
                SELECT notification_id, type
                FROM notifications
                WHERE recipient_id = %s
                  AND type IN ('LOW_STOCK', 'OUT_OF_STOCK')
                  AND is_read = 0
                  AND message LIKE %s
                LIMIT 1
            ''', (caregiver, f'%{agg["medication_name"]}%'))
            existing = cursor.fetchone()

            if existing:
                # 已有未读通知 → 更新内容（可能升级类型或刷新消息）
                if existing['type'] != notif_type:
                    cursor.execute('''
                        UPDATE notifications
                        SET title = %s, message = %s, type = %s, created_at = NOW()
                        WHERE notification_id = %s
                    ''', (title, message, notif_type, existing['notification_id']))
                else:
                    cursor.execute('''
                        UPDATE notifications
                        SET message = %s, created_at = NOW()
                        WHERE notification_id = %s
                    ''', (message, existing['notification_id']))
            else:
                # 没有未读通知 → 插入新记录
                cursor.execute('''
                    INSERT INTO notifications (recipient_id, title, message, type, is_read, created_at)
                    VALUES (%s, %s, %s, %s, 0, NOW())
                ''', (caregiver, title, message, notif_type))
                created += 1

        conn.commit()
        cursor.close()
    return created

def sync_caregiver_stock_notifications(caregiver_id):
    return sync_stock_notifications(caregiver_id=caregiver_id)


def sync_patient_caregiver_stock_notifications(patient_id):
    return sync_stock_notifications(patient_id=patient_id)


def sync_prescription_stock_notifications(prescription_id):
    return sync_stock_notifications(prescription_id=prescription_id)


def sync_medication_stock_notifications(medication_id):
    return sync_stock_notifications(medication_id=medication_id)
