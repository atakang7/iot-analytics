"""
PostgreSQL Database

Simple SQLAlchemy session factory.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

Base = declarative_base()


class Database:
    def __init__(self, url: str):
        self.engine = create_engine(url)
        self.Session = sessionmaker(bind=self.engine)
    
    def create_tables(self):
        Base.metadata.create_all(self.engine)
    
    def session(self):
        return self.Session()
