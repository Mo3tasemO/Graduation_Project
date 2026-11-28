from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class PhraseCreate(BaseModel):
    text: str = Field(min_length=1, max_length=100)

    @field_validator("text")
    @classmethod
    def trim_text(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("Phrase must not be empty.")
        return value


class PhraseResponse(BaseModel):
    id: int
    text: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SpeechHistoryCreate(BaseModel):
    text: str = Field(min_length=1, max_length=500)

    @field_validator("text")
    @classmethod
    def trim_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Message must not be empty.")
        return value


class SpeechHistoryResponse(BaseModel):
    id: int
    text: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SpeechPreferences(BaseModel):
    language: str = Field(default="en-US", min_length=2, max_length=64)
    voice_name: str | None = Field(default=None, max_length=160)
    voice_locale: str | None = Field(default=None, max_length=64)
    rate: float = Field(default=0.45, ge=0.1, le=1.0)
    volume: float = Field(default=1.0, ge=0.0, le=1.0)

    model_config = ConfigDict(from_attributes=True)


class HomeMessage(BaseModel):
    message: str
