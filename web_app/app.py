# app.py, this is the main file
from myproject import app #import app from the __init__.py file
from flask import render_template



@app.route('/')
def INDEX():
    return render_template('home.html')

if __name__ == '__main__':
    app.run(debug=True)
    #app.run(host='0.0.0.0', port=80) 
