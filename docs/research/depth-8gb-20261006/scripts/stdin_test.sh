cd /c/bonsai/8gb
python -c "import subprocess; r=subprocess.run(['python','-c','print(7*6)'],capture_output=True,text=True); print('child said', r.stdout.strip())" < /dev/null > receipts/stdin_test.txt 2>&1
python -c "import subprocess; r=subprocess.run(['python','-c','print(7*6)'],capture_output=True,text=True); print('child said', r.stdout.strip())" > receipts/stdin_test_nofix.txt 2>&1
