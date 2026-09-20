import time

print("Task started... waiting for 30 seconds.")
time.sleep(30)

with open("done.txt", "w") as f:
    f.write("Task Completed Successfully!")

print("done.txt file created!")
