from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import os
import psycopg2

# Configuration
POSTGRES_HOST = os.environ.get('POSTGRES_HOST')
POSTGRES_DB = os.environ.get('POSTGRES_DB')
POSTGRES_USER = os.environ.get('POSTGRES_USER')
POSTGRES_PASSWORD = os.environ.get('POSTGRES_PASSWORD')

# FastAPI application
app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

def get_db_connection():
    conn = psycopg2.connect(
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        host=POSTGRES_HOST,
        database=POSTGRES_DB
    )
    return conn

def setup_database():
    # Establishing a new connection to our database
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Create table if it doesn't exist
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS visit_counter (
                    counter_name VARCHAR PRIMARY KEY,
                    count_value INT NOT NULL
                );
            """)
            # Initialize the counter if it doesn't exist
            cursor.execute("""
                INSERT INTO visit_counter (counter_name, count_value)
                VALUES ('hits', 0)
                ON CONFLICT (counter_name) DO NOTHING;
            """)
        # Committing any changes and closing the transaction
        conn.commit()
    finally:
        # Closing the database connection
        conn.close()

@app.on_event("startup")
async def startup_event():
    # Setting up database during startup
    setup_database()

@app.get('/', response_class=HTMLResponse)
async def read_root(request: Request):
    # Each request gets a new database connection
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Increment the counter and retrieve its value
            cursor.execute("UPDATE visit_counter SET count_value = count_value + 1 WHERE counter_name = 'hits';")
            cursor.execute("SELECT count_value FROM visit_counter WHERE counter_name = 'hits';")
            count = cursor.fetchone()[0]
        # Committing the update
        conn.commit()
    finally:
        # Closing the connection
        conn.close()

    # Returning the current counter value within the rendered HTML
    return templates.TemplateResponse("index.html", {"request": request, "counter": count})
