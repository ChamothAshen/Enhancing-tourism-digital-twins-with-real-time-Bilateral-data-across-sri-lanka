"""
Authentication models and schemas for admin users.
"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime


class AdminRegister(BaseModel):
    """Model for admin registration"""
    name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=6)
    phone: Optional[str] = Field(None, max_length=20)


class AdminLogin(BaseModel):
    """Model for admin login"""
    email: EmailStr
    password: str


class AdminResponse(BaseModel):
    """Model for admin response (without password)"""
    id: str
    name: str
    email: str
    phone: Optional[str] = None
    created_at: datetime
    token: str


class AdminInDB(BaseModel):
    """Model for admin stored in database"""
    name: str
    email: str
    hashed_password: str
    phone: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    is_active: bool = True
