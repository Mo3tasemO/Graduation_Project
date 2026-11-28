from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from .home_schemas import (
    HomeMessage,
    PhraseCreate,
    PhraseResponse,
    SpeechHistoryCreate,
    SpeechHistoryResponse,
    SpeechPreferences,
)
from .models import CustomPhrase, MessageHistory, SpeechPreference, User
from .routes import get_current_user, get_session

router = APIRouter(prefix="/api/v1/home", tags=["Home"])
HISTORY_LIMIT = 100
HISTORY_RETENTION = 200
CUSTOM_PHRASE_LIMIT = 50


@router.get("/phrases", response_model=list[PhraseResponse])
def list_phrases(
    user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_session)],
) -> list[CustomPhrase]:
    return list(
        session.scalars(
            select(CustomPhrase)
            .where(CustomPhrase.user_id == user.id)
            .order_by(CustomPhrase.created_at, CustomPhrase.id)
        )
    )


@router.post("/phrases", response_model=PhraseResponse, status_code=status.HTTP_201_CREATED)
def create_phrase(
    payload: PhraseCreate,
    user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_session)],
) -> CustomPhrase:
    phrase_count = session.scalar(
        select(func.count()).select_from(CustomPhrase).where(CustomPhrase.user_id == user.id)
    ) or 0
    if phrase_count >= CUSTOM_PHRASE_LIMIT:
        raise HTTPException(status_code=409, detail="You have reached the 50 saved phrase limit.")
    duplicate = session.scalar(
        select(CustomPhrase.id).where(
            CustomPhrase.user_id == user.id,
            func.lower(CustomPhrase.text) == payload.text.lower(),
        )
    )
    if duplicate is not None:
        raise HTTPException(status_code=409, detail="That phrase is already saved.")
    now = datetime.now(timezone.utc)
    phrase = CustomPhrase(user_id=user.id, text=payload.text, created_at=now, updated_at=now)
    session.add(phrase)
    session.commit()
    session.refresh(phrase)
    return phrase


@router.put("/phrases/{phrase_id}", response_model=PhraseResponse)
def update_phrase(
    phrase_id: int,
    payload: PhraseCreate,
    user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_session)],
) -> CustomPhrase:
    phrase = session.scalar(
        select(CustomPhrase).where(CustomPhrase.id == phrase_id, CustomPhrase.user_id == user.id)
    )
    if phrase is None:
        raise HTTPException(status_code=404, detail="Saved phrase was not found.")
    duplicate = session.scalar(
        select(CustomPhrase.id).where(
            CustomPhrase.user_id == user.id,
            CustomPhrase.id != phrase_id,
            func.lower(CustomPhrase.text) == payload.text.lower(),
        )
    )
    if duplicate is not None:
        raise HTTPException(status_code=409, detail="That phrase is already saved.")
    phrase.text = payload.text
    phrase.updated_at = datetime.now(timezone.utc)
    session.commit()
    session.refresh(phrase)
    return phrase


@router.delete("/phrases/{phrase_id}", response_model=HomeMessage)
def delete_phrase(
    phrase_id: int,
    user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_session)],
) -> HomeMessage:
    phrase = session.scalar(
        select(CustomPhrase).where(CustomPhrase.id == phrase_id, CustomPhrase.user_id == user.id)
    )
    if phrase is None:
        raise HTTPException(status_code=404, detail="Saved phrase was not found.")
    session.delete(phrase)
    session.commit()
    return HomeMessage(message="Saved phrase deleted.")


@router.get("/history", response_model=list[SpeechHistoryResponse])
def list_history(
    user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_session)],
    limit: int = Query(default=50, ge=1, le=HISTORY_LIMIT),
) -> list[MessageHistory]:
    return list(
        session.scalars(
            select(MessageHistory)
            .where(MessageHistory.user_id == user.id)
            .order_by(MessageHistory.created_at.desc(), MessageHistory.id.desc())
            .limit(limit)
        )
    )


@router.post("/history", response_model=SpeechHistoryResponse, status_code=status.HTTP_201_CREATED)
def create_history_entry(
    payload: SpeechHistoryCreate,
    user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_session)],
) -> MessageHistory:
    entry = MessageHistory(user_id=user.id, text=payload.text)
    session.add(entry)
    session.flush()
    # Keep a bounded per-user history without logging message contents.
    stale_ids = session.scalars(
        select(MessageHistory.id)
        .where(MessageHistory.user_id == user.id)
        .order_by(MessageHistory.created_at.desc(), MessageHistory.id.desc())
        .offset(HISTORY_RETENTION)
    ).all()
    if stale_ids:
        session.execute(
            delete(MessageHistory).where(
                MessageHistory.user_id == user.id, MessageHistory.id.in_(stale_ids)
            )
        )
    session.commit()
    session.refresh(entry)
    return entry


@router.delete("/history", response_model=HomeMessage)
def clear_history(
    user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_session)],
) -> HomeMessage:
    session.execute(delete(MessageHistory).where(MessageHistory.user_id == user.id))
    session.commit()
    return HomeMessage(message="Message history cleared.")


@router.delete("/history/{entry_id}", response_model=HomeMessage)
def delete_history_entry(
    entry_id: int,
    user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_session)],
) -> HomeMessage:
    entry = session.scalar(
        select(MessageHistory).where(MessageHistory.id == entry_id, MessageHistory.user_id == user.id)
    )
    if entry is None:
        raise HTTPException(status_code=404, detail="History entry was not found.")
    session.delete(entry)
    session.commit()
    return HomeMessage(message="History entry deleted.")


@router.get("/preferences", response_model=SpeechPreferences)
def get_preferences(
    user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_session)],
) -> SpeechPreference | SpeechPreferences:
    saved = session.get(SpeechPreference, user.id)
    if saved is None:
        return SpeechPreferences()
    return saved


@router.put("/preferences", response_model=SpeechPreferences)
def save_preferences(
    payload: SpeechPreferences,
    user: Annotated[User, Depends(get_current_user)],
    session: Annotated[Session, Depends(get_session)],
) -> SpeechPreference:
    saved = session.get(SpeechPreference, user.id)
    values = payload.model_dump()
    if saved is None:
        saved = SpeechPreference(user_id=user.id, **values)
        session.add(saved)
    else:
        for key, value in values.items():
            setattr(saved, key, value)
        saved.updated_at = datetime.now(timezone.utc)
    session.commit()
    session.refresh(saved)
    return saved
