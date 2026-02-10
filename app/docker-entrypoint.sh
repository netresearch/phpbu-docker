#!/bin/sh
# Apply PHP timezone from TZ environment variable at runtime
if [ -n "$TZ" ]; then
    if printf '%s' "$TZ" | grep -Eq '^[A-Za-z0-9/_+.-]+$'; then
        printf 'date.timezone = %s\n' "$TZ" > /usr/local/etc/php/conf.d/tz.ini
    else
        printf 'Warning: Invalid TZ value ignored\n' >&2
    fi
fi

exec /app/vendor/bin/phpbu "$@"
