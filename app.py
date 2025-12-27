from flask import Flask, render_template, jsonify
import psutil
import datetime
import redis
import os
import ast
import platform

app = Flask(__name__)

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))

try:
    redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
    redis_client.ping()
except redis.exceptions.ConnectionError:
    print("⚠️ Warning: Redis is not running! Metrics won't be saved.")
    redis_client = None

def get_system_metrics():
    metrics = {
        'time': datetime.datetime.now().strftime('%d %b %Y time: %H:%M:%S'),
        'cpu': psutil.cpu_percent(interval=1),
        'memory': psutil.virtual_memory().percent,
        'disk': psutil.disk_usage('/').percent,
        'net_sent': psutil.net_io_counters().bytes_sent / 1024 / 1024,  # MB
        'net_recv': psutil.net_io_counters().bytes_recv / 1024 / 1024,  # MB,
        'processes': len(list(psutil.process_iter()))
    }
    if platform.system() in ['Linux', 'Darwin']:
        try:
            metrics['load'] = os.getloadavg()[0]
        except OSError:
            metrics['load'] = 0.0
    else:
        metrics['load'] = 0.0

    if redis_client:
        redis_client.lpush("metrics", str(metrics))
        redis_client.ltrim("metrics", 0, 4)

    return metrics

@app.route('/')
def index():
    if not redis_client:
        metrics = get_system_metrics()
    else:
        metrics_list = redis_client.lrange("metrics", 0, 0)
        if metrics_list:
            metrics = ast.literal_eval(metrics_list[0])
        else:
            metrics = get_system_metrics()
    return render_template('index.html', metrics=metrics)

@app.route('/metrics')
def metrics():
    return jsonify(get_system_metrics())

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)