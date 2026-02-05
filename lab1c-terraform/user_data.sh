#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y python3-pip amazon-cloudwatch-agent

pip3 install flask pymysql boto3

# ----------------------------
# App setup
# ----------------------------
mkdir -p /opt/rdsapp
mkdir -p /var/log/rdsapp
chmod 755 /var/log/rdsapp

cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import boto3
import pymysql
from flask import Flask, request
import logging
logging.basicConfig(level=logging.INFO)

# ----------------------------
# AWS clients
# ----------------------------
REGION = os.environ.get("AWS_REGION", "us-east-2")
SECRET_ID = os.environ.get("SECRET_ID", "${local.name_prefix}/rds/mysql-${random_id.secret_suffix.hex}")

secrets = boto3.client("secretsmanager", region_name=REGION)
cloudwatch = boto3.client("cloudwatch", region_name=REGION)

# ----------------------------
# Helpers
# ----------------------------
def emit_db_connection_error():
    cloudwatch.put_metric_data(
        Namespace="Lab/RDSApp",
        MetricData=[
            {
                "MetricName": "DBConnectionErrors",
                "Value": 1,
                "Unit": "Count"
            }
        ]
    )

def get_db_creds():
    resp = secrets.get_secret_value(SecretId=SECRET_ID)
    return json.loads(resp["SecretString"])

def get_conn():
    try:
        creds = get_db_creds()
        return pymysql.connect(
            host=creds["host"],
            user=creds["username"],
            password=creds["password"],
            database=creds.get("dbname", "labdc"),
            port=int(creds.get("port", 3306)),
            autocommit=True,
            connect_timeout=5
        )
    except Exception as e:
        logging.exception("ERROR: DB connection failed")  # <-- this is what your filter matches
        emit_db_connection_error()
        raise

# ----------------------------
# Flask app
# ----------------------------
app = Flask(__name__)

@app.route("/")
def home():
    return "<h3>EC2 → RDS App</h3><p>Try /add?note=hello or /list</p>"

@app.route("/init")
def init_db():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS notes (id INT AUTO_INCREMENT PRIMARY KEY, note VARCHAR(255));")
    cur.close()
    conn.close()
    return "DB initialized."

@app.route("/add")
def add_note():
    note = request.args.get("note", "").strip()
    if not note:
        return "Missing note param", 400

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("INSERT INTO notes(note) VALUES (%s)", (note,))
    cur.close()
    conn.close()
    return f"Inserted note: {note}"

@app.route("/list")
def list_notes():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, note FROM notes ORDER BY id DESC")
    rows = cur.fetchall()
    cur.close()
    conn.close()

    out = "<ul>"
    for r in rows:
        out += f"<li>{r[0]}: {r[1]}</li>"
    out += "</ul>"
    return out

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY


cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=SECRET_ID=${local.name_prefix}/rds/mysql-${random_id.secret_suffix.hex}
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always

# Write app logs to files (so CloudWatch Agent can ship them)
StandardOutput=append:/var/log/rdsapp/rdsapp.log
StandardError=append:/var/log/rdsapp/rdsapp.err

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp

# ----------------------------
# CloudWatch Agent config
# ----------------------------
cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CW'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/rdsapp/rdsapp.log",
            "log_group_name": "/aws/ec2/lab1c-rds-app",
            "log_stream_name": "{instance_id}/app",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/rdsapp/rdsapp.err",
            "log_group_name": "/aws/ec2/lab1c-rds-app",
            "log_stream_name": "{instance_id}/err",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/lab1c-rds-app",
            "log_stream_name": "{instance_id}/messages",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CW



/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s
