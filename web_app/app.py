# app.py, this is the main file
from myproject import app #import app from the __init__.py file
from flask import render_template

###############Commented out code for production only
#from flask_limiter import Limiter
#from flask_limiter.util import get_remote_address

# set request limits to website. Limit 50,000 requests per day
#limiter = Limiter(
#    get_remote_address,
#    app=app,
#    default_limits=["50000 per day"],
#    storage_uri="memcached://localhost:11211",
#)

@app.route('/')
def INDEX():
    return render_template('home.html')

if __name__ == '__main__':
    app.run(debug=True)
    #app.run(host='0.0.0.0', port=80)
