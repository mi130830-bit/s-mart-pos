import cv2
import time
import requests
import subprocess
import os
import sys
import asyncio
import edge_tts

API_URL = "http://192.168.1.204:8000/api/v1/recognize"
GREETING_COOLDOWN_SEC = 120 # 2 minutes audio cooldown per person
VOICE_CACHE_DIR = r"C:\pos_desktop\voice_cache"
DEFAULT_VOICE = "th-TH-PremwadeeNeural" # เสียงผู้หญิงธรรมชาติ สุภาพ นุ่มนวล (น้องเจนนี่)

os.makedirs(VOICE_CACHE_DIR, exist_ok=True)
last_spoken_times = {}

async def generate_voice_file(text, filepath):
    comm = edge_tts.Communicate(text, DEFAULT_VOICE)
    await comm.save(filepath)

def play_audio(filepath):
    ps_cmd = f'''
Add-Type -AssemblyName presentationCore
$player = New-Object System.Windows.Media.MediaPlayer
$player.Open('{filepath}')
$player.Play()
Start-Sleep -Seconds 4
'''
    subprocess.Popen(["powershell", "-NoProfile", "-Command", ps_cmd], 
                     creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)

def speak_thai(name, text):
    clean_name = "".join([c for c in name if c.isalnum() or c in (' ', '_')]).rstrip()
    if not clean_name:
        clean_name = "customer"
    filepath = os.path.join(VOICE_CACHE_DIR, f"{clean_name}.mp3")

    if not os.path.exists(filepath):
        try:
            asyncio.run(generate_voice_file(text, filepath))
        except Exception as e:
            print(f"Voice generation error: {e}")

    if os.path.exists(filepath):
        play_audio(filepath)

def main():
    is_headless = "--headless" in sys.argv or "-h" in sys.argv
    print("================================================================")
    print("🚀 เริ่มต้นระบบ AI กล้องตรวจจับใบหน้าหน้าร้าน (SmartPOS Face Receptionist)")
    print(f"📡 สมองกล AI Mini PC: {API_URL}")
    print(f"🖥️ Mode: {'Background (Headless)' if is_headless else 'GUI Window'}")
    print("================================================================")

    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
    if not cap.isOpened():
        cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("⚠️ ไม่พบอุปกรณ์ Webcam (ข้ามการทำงานกล้องต้อนรับ)")
        return

    last_check_time = 0
    detected_info = "Status: Monitoring..."
    info_color = (200, 200, 200)

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                time.sleep(0.5)
                continue

            now = time.time()

            # Process frame every 1.0 second
            if now - last_check_time > 1.0:
                last_check_time = now
                _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
                
                try:
                    files = {'image': ('frame.jpg', buffer.tobytes(), 'image/jpeg')}
                    resp = requests.post(API_URL, files=files, timeout=2.5)
                    if resp.status_code == 200:
                        data = resp.json()
                        if data.get("match"):
                            name = data.get("name")
                            role = data.get("role")
                            greeting = data.get("greeting", f"สวัสดีค่ะ คุณ {name} ยินดีต้อนรับนะคะ")

                            detected_info = f"MATCHED: {name} ({role})"
                            info_color = (0, 255, 0)

                            last_spoken = last_spoken_times.get(name, 0)
                            if now - last_spoken > GREETING_COOLDOWN_SEC:
                                last_spoken_times[name] = now
                                print(f"\n🎉 [AI RECEPTION] ตรวจพบ: {name} ({role})")
                                print(f"🔊 ส่งเสียงทักทาย (Neural Voice): '{greeting}'")
                                if data.get("telegram_sent"):
                                    print(f"📲 ส่งแจ้งเตือน Telegram สำเร็จ!")
                                speak_thai(name, greeting)
                        else:
                            reason = data.get("reason")
                            if reason == "no_face_detected":
                                detected_info = "Status: Waiting for face..."
                                info_color = (150, 150, 150)
                            else:
                                detected_info = "Status: Unknown Customer"
                                info_color = (0, 165, 255)
                except Exception:
                    detected_info = "Status: AI Server Standby"
                    info_color = (0, 0, 255)

            if not is_headless:
                h, w, _ = frame.shape
                cv2.rectangle(frame, (0, 0), (w, 45), (30, 30, 30), -1)
                cv2.putText(frame, "SmartPOS AI Face Receptionist - S.Service Tha Kham", (15, 30), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.65, (255, 255, 255), 2)

                cv2.rectangle(frame, (0, h - 45), (w, h), (20, 20, 20), -1)
                cv2.putText(frame, detected_info, (15, h - 15), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.65, info_color, 2)

                cv2.imshow("SmartPOS Face Receptionist Camera", frame)
                key = cv2.waitKey(1) & 0xFF
                if key == ord('q') or key == 27:
                    break
            else:
                time.sleep(0.05)
    except KeyboardInterrupt:
        pass
    finally:
        cap.release()
        if not is_headless:
            cv2.destroyAllWindows()
        print("🛑 ปิดระบบ AI กล้องตรวจจับใบหน้าเรียบร้อย")

if __name__ == '__main__':
    main()
