import pytest
from requests import RequestException

from ekadashi_billing.play import (
    GooglePublisher,
    PublisherUnavailable,
    PurchaseRejected,
    ReceiptChanged,
)


class Response:
    def __init__(self, status):
        self.status_code = status
        self.content = b""


class Session:
    def __init__(self, status=204):
        self.status = status
        self.calls = []

    def request(self, method, url, **kwargs):
        self.calls.append((method, url, kwargs))
        if self.status == "network":
            raise RequestException("sensitive-token-must-not-escape")
        return Response(self.status)


@pytest.mark.parametrize(
    "status,exception",
    [
        (401, PublisherUnavailable),
        (403, PublisherUnavailable),
        (429, PublisherUnavailable),
        (503, PublisherUnavailable),
        ("network", PublisherUnavailable),
        (409, ReceiptChanged),
        (412, ReceiptChanged),
        (400, PurchaseRejected),
    ],
)
def test_failure_classification_sanitized(clock, status, exception):
    p = GooglePublisher(clock, session=Session(status))
    with pytest.raises(exception) as exc:
        p.acknowledge("sensitive-token", "ekadashi_premium")
    assert "sensitive-token" not in str(exc.value)


def test_v2_deferral_uses_etag_duration_and_no_validation_only(clock):
    session = Session()
    p = GooglePublisher(clock, session=session)
    p.defer("token/escaped", "etag-original", 123)
    method, url, kwargs = session.calls[0]
    assert method == "POST" and "/purchases/subscriptionsv2/tokens/token%2Fescaped:defer" in url
    assert kwargs["json"] == {
        "deferralContext": {
            "etag": "etag-original",
            "deferDuration": "123s",
            "validateOnly": False,
        }
    }
    assert kwargs["timeout"] == 10


@pytest.mark.parametrize("etag,duration", [(None, 123), ("etag", 0), ("etag", -1)])
def test_invalid_deferrals_never_contact_play(clock, etag, duration):
    session = Session()
    p = GooglePublisher(clock, session=session)
    with pytest.raises(PurchaseRejected):
        p.defer("token", etag, duration)
    assert session.calls == []
