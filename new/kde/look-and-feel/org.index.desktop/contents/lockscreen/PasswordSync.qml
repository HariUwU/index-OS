// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

// Match Plasma's shared-engine password synchronization across lock surfaces.
// This is only an in-memory editing buffer, cleared immediately on submission.
QtObject {
    property string password: ""
}
