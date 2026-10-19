// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

Kirigami.FormLayout {
    id: form

    // Native screen-lock KCM ShellConfig.qml bridges these cfg_ properties to
    // the shell's config.xml schema, including reset/default handling.
    property alias cfg_indexIntro: introToggle.checked
    property bool cfg_indexIntroDefault: true
    property real cfg_indexVolume: 0.3
    property real cfg_indexVolumeDefault: 0.3
    twinFormLayouts: parentLayout

    Controls.CheckBox {
        id: introToggle
        Kirigami.FormData.label: i18n("INDEX intro:")
        text: i18n("Play the original cinematic intro")
        checked: true
        KCM.SettingHighlighter {
            highlight: form.cfg_indexIntro !== form.cfg_indexIntroDefault
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Audio volume:")
        Controls.Slider {
            id: volumeSlider
            from: 0; to: 1; stepSize: 0.05
            value: form.cfg_indexVolume
            onMoved: form.cfg_indexVolume = value
            Accessible.name: i18n("Lock screen audio volume")
            KCM.SettingHighlighter {
                highlight: Math.abs(form.cfg_indexVolume - form.cfg_indexVolumeDefault) > 0.001
            }
        }
        Controls.Label {
            text: Math.round(form.cfg_indexVolume * 100) + "%"
            Layout.minimumWidth: implicitWidth
        }
    }
}
