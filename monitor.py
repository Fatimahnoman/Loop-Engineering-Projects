import time
import os

print("Monitoring started... checking every 60 seconds for done.txt")

while True:
    if os.path.exists("done.txt"):
        print("Loop finished!")
        break
    print("done.txt not found yet. Waiting 60 seconds...")
    time.sleep(60)
