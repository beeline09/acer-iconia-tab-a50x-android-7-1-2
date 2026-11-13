$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)
$(call inherit-product, device/samsung/p4-common/p4-common.mk)
$(call inherit-product, device/acer/picasso/device.mk)
$(call inherit-product-if-exists, vendor/acer/picasso/picasso-vendor.mk)

PRODUCT_NAME := picasso
PRODUCT_BRAND := Acer
PRODUCT_DEVICE := picasso
PRODUCT_MODEL := Iconia Tab A500
PRODUCT_MANUFACTURER := Acer
