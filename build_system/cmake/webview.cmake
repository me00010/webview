# Avoid warning related to FetchContent and DOWNLOAD_EXTRACT_TIMESTAMP
if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()

macro(webview_options)
    set(WEBVIEW_BACKEND_COCOA cocoa)
    set(WEBVIEW_BACKEND_EDGE edge)
    set(WEBVIEW_BACKEND_GTK gtk)

    if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
        set(WEBVIEW_BACKEND "${WEBVIEW_BACKEND_COCOA}" CACHE STRING "")
    elseif(CMAKE_SYSTEM_NAME STREQUAL Linux)
        set(WEBVIEW_BACKEND "${WEBVIEW_BACKEND_GTK}" CACHE STRING "")
        # Oldest versions of libraries supported by Debian.
        # Oldest supported Debian is Debian 10 (Buster) as of 2023-09-12.
        set(WEBVIEW_WEBKITGTK_PKGCONFIG_LIBRARY webkit2gtk-4.0)
        set(WEBVIEW_WEBKITGTK_PKGCONFIG_MIN_VERSION 2.34)
        set(WEBVIEW_GTK_PKGCONFIG_LIBRARY gtk+-3.0)
        set(WEBVIEW_GTK_PKGCONFIG_MIN_VERSION 3.24)
    elseif(CMAKE_SYSTEM_NAME STREQUAL Windows)
        set(WEBVIEW_BACKEND "${WEBVIEW_BACKEND_EDGE}" CACHE STRING "")
        set(WEBVIEW_MSWEBVIEW2_VERSION "1.0.1150.38" CACHE STRING "")
        option(WEBVIEW_USE_BUILTIN_MSWEBVIEW2 "" ON)
    else()
        message(FATAL_ERROR "Unsupported platform.")
    endif()

    option(WEBVIEW_FETCH_MISSING_DEPENDENCIES "" ON)
endmacro()

macro(webview_find_dependencies)
    if(CMAKE_SYSTEM_NAME STREQUAL Darwin AND WEBVIEW_BACKEND STREQUAL WEBVIEW_BACKEND_COCOA)
        find_library(WEBKIT_WEBKIT_LIBRARY WebKit REQUIRED)
        list(APPEND WEBVIEW_DEPENDENCIES ${WEBKIT_WEBKIT_LIBRARY})
    elseif(CMAKE_SYSTEM_NAME STREQUAL Linux AND WEBVIEW_BACKEND STREQUAL WEBVIEW_BACKEND_GTK)
        find_package(PkgConfig REQUIRED)
        pkg_check_modules(WEBKITGTK REQUIRED IMPORTED_TARGET
            "${WEBVIEW_WEBKITGTK_PKGCONFIG_LIBRARY}>=${WEBVIEW_WEBKITGTK_PKGCONFIG_MIN_VERSION}")
        pkg_check_modules(GTK REQUIRED IMPORTED_TARGET
            "${WEBVIEW_GTK_PKGCONFIG_LIBRARY}>=${WEBVIEW_GTK_PKGCONFIG_MIN_VERSION}")
        set(WEBVIEW_WEBKITGTK_TARGET PkgConfig::WEBKITGTK CACHE STRING "")
        set(WEBVIEW_GTK_TARGET PkgConfig::GTK CACHE STRING "")
        list(APPEND WEBVIEW_DEPENDENCIES ${WEBVIEW_WEBKITGTK_TARGET} ${WEBVIEW_GTK_TARGET})
    elseif(CMAKE_SYSTEM_NAME STREQUAL Windows AND WEBVIEW_BACKEND STREQUAL WEBVIEW_BACKEND_EDGE)
        if(WEBVIEW_USE_BUILTIN_MSWEBVIEW2)
            find_package(MSWebView2 QUIET)
            if(NOT MSWebView2_FOUND AND WEBVIEW_FETCH_MISSING_DEPENDENCIES)
                webview_fetch_mswebview2(${WEBVIEW_MSWEBVIEW2_VERSION})
            endif()
            find_package(MSWebView2 REQUIRED)
            if(MSWebView2_FOUND)
                set(WEBVIEW_MSWEBVIEW2_TARGET MSWebView2::headers)
                list(APPEND WEBVIEW_DEPENDENCIES ${WEBVIEW_MSWEBVIEW2_TARGET})
            endif()
        endif()
        list(APPEND WEBVIEW_DEPENDENCIES advapi32 ole32 shell32 shlwapi user32 version)
    else()
        message(FATAL_ERROR "Invalid platform/backend combination.")
    endif()
endmacro()

function(webview_fetch_mswebview2 VERSION)
    if(NOT COMMAND FetchContent_Declare)
        include(FetchContent)
    endif()
    set(FC_NAME microsoft_web_webview2)
    FetchContent_Declare(${FC_NAME}
        URL "https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/${VERSION}"
        CONFIGURE_COMMAND "")
    FetchContent_GetProperties(${FC_NAME})
    if(NOT ${FC_NAME}_POPULATED)
        FetchContent_Populate(${FC_NAME})
        set(MSWebView2_ROOT "${${FC_NAME}_SOURCE_DIR}" PARENT_SCOPE)
    endif()
endfunction()
