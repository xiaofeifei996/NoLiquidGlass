TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NoLiquidGlass

NoLiquidGlass_FILES = Hooks/NoLiquidGlass.xm
NoLiquidGlass_CFLAGS = -fobjc-arc -fvisibility=hidden
NoLiquidGlass_FRAMEWORKS = UIKit
NoLiquidGlass_LIBRARIES = substrate
NoLiquidGlass_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk
