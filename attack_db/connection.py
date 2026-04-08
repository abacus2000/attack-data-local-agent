
from neo4j import GraphDatabase
from os import environ
from dotenv import load_dotenv
from pathlib import Path

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

URI = environ.get("NEO4J_URI")
USER = environ.get("NEO4J_USER")
PASSWORD = environ.get("NEO4J_PASSWORD")

driver = GraphDatabase.driver(URI, auth=(USER, PASSWORD))
