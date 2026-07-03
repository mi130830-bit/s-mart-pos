import pymysql
import sys

try:
    conn = pymysql.connect(
        host='127.0.0.1',
        user='root',
        password='',
        database='s_mart'
    )
    with conn.cursor(pymysql.cursors.DictCursor) as cursor:
        cursor.execute("SELECT id, employee_id, pay_cycle, period_start, period_end, status FROM payroll_record;")
        rows = cursor.fetchall()
        for row in rows:
            print(f"ID: {row['id']}, Emp: {row['employee_id']}, Cycle: {row['pay_cycle']}, Start: {row['period_start']}, End: {row['period_end']}, Status: {row['status']}")
except Exception as e:
    print(f"Error: {e}")
