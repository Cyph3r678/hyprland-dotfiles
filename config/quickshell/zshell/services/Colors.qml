pragma Singleton
import QtQuick

// Central design-token singleton.
// Every visual component should pull colors/radii/fonts from here
// instead of hardcoding hex values, so restyling only ever happens
// in one place.
QtObject {
    // ---- palette (from your palette.css) ----
    readonly property color bg0: "#191919"   // outer panel background
    readonly property color bg1: "#202020"   // card background
    readonly property color bgX: "#161616"
    readonly property color bg2: "#272727"   

    readonly property color red: "#fa456c"
    readonly property color vol: "#A7354D"
    readonly property color hovered: "#FC5D81"
    
    readonly property color yellow: "#eba86d"
    readonly property color green: "#49bd7d"
    readonly property color aqua: "#387bdf"
    
    readonly property color blue: "#7769fa"  
    readonly property color bb: "#473E98"
    readonly property color hoverblue: "#8B7FFD"


    readonly property color purple: "#944edf"

    readonly property color fg: "#E8E8E8"          // primary text
    readonly property color fgMuted: "#9a9a9a"      // secondary/dim text

    // ---- shape ----
    readonly property int radiusOuter: 15
    readonly property int radiusCard: 10
    readonly property int radiusTile: 10
    readonly property int radiusPill: 999

    // ---- spacing ----
    readonly property int gapLg: 16
    readonly property int gapMd: 12
    readonly property int gapSm: 8
    readonly property int panelPadding: 16

    // ---- type ----
    // Swap this once you know which font your Figma file actually uses.
    readonly property string fontFamily: "Modulus Pro Semi Bold"
}