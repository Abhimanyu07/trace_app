import datetime
from fastapi import APIRouter, Query
from pydantic import BaseModel
from ..config import get_device_id, get_device_name
from ..db.database import (
    get_usage_today, get_usage_range, get_daily_summary,
    get_weekly_summary, get_hourly_breakdown, get_all_apps,
    get_all_domains, set_app_category,
)
from ..tracker.macos import tracker

router = APIRouter(prefix="/usage", tags=["usage"])


class CategoryUpdate(BaseModel):
    category: str  # 'productive', 'neutral', 'distraction'


def _date_to_ts(date_str: str) -> int:
    d = datetime.datetime.strptime(date_str, "%Y-%m-%d")
    return int(d.timestamp())


def _wrap_response(data: dict) -> dict:
    """Add device info to every response."""
    data["device_id"] = get_device_id()
    data["device_name"] = get_device_name()
    data["device_type"] = "desktop"
    return data


@router.get("/today")
async def usage_today():
    records = get_usage_today()
    return _wrap_response({"records": records})


@router.get("/range")
async def usage_range(
    start: str = Query(..., description="YYYY-MM-DD"),
    end: str = Query(..., description="YYYY-MM-DD"),
):
    records = get_usage_range(_date_to_ts(start), _date_to_ts(end))
    return _wrap_response({"records": records})


@router.get("/summary/daily")
async def daily_summary(date: str = Query(None, description="YYYY-MM-DD")):
    if date is None:
        date_ts = _date_to_ts(datetime.date.today().isoformat())
    else:
        date_ts = _date_to_ts(date)
    summary = get_daily_summary(date_ts)
    return _wrap_response(summary)


@router.get("/summary/weekly")
async def weekly_summary(week_start: str = Query(None, description="YYYY-MM-DD (Monday)")):
    if week_start is None:
        today = datetime.date.today()
        monday = today - datetime.timedelta(days=today.weekday())
        week_start_ts = _date_to_ts(monday.isoformat())
    else:
        week_start_ts = _date_to_ts(week_start)
    summaries = get_weekly_summary(week_start_ts)
    return _wrap_response({"days": summaries})


@router.get("/hourly")
async def hourly_breakdown(date: str = Query(None, description="YYYY-MM-DD")):
    if date is None:
        date_ts = _date_to_ts(datetime.date.today().isoformat())
    else:
        date_ts = _date_to_ts(date)
    hours = get_hourly_breakdown(date_ts)
    return _wrap_response({"hours": hours})


@router.get("/apps")
async def all_apps():
    apps = get_all_apps()
    return _wrap_response({"apps": apps})


@router.get("/domains")
async def all_domains():
    domains = get_all_domains()
    return _wrap_response({"domains": domains})


@router.put("/apps/{app_name}/category")
async def update_category(app_name: str, body: CategoryUpdate):
    if body.category not in ("productive", "neutral", "distraction"):
        return {"error": "Category must be productive, neutral, or distraction"}
    set_app_category(app_name, body.category)
    return {"success": True, "app_name": app_name, "category": body.category}


@router.get("/current")
async def current_window():
    current = tracker.get_current()
    if not current:
        return _wrap_response({"active": False, "is_paused": tracker.is_paused})
    return _wrap_response({"active": True, "is_paused": tracker.is_paused, **current})


@router.get("/status")
async def tracker_status():
    return _wrap_response({"is_paused": tracker.is_paused})
