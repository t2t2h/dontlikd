export TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AgoraEnhance
AgoraEnhance_FILES = Tweak.x
AgoraEnhance_CFLAGS = -fobjc-arc
AgoraEnhance_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
