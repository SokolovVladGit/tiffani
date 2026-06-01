import '../../domain/entities/admin_native_product_form.dart';

class AdminNativeProductPayloadDto {
  final AdminNativeProductForm form;

  const AdminNativeProductPayloadDto(this.form);

  Map<String, dynamic> toJson() {
    final productId = form.productId?.trim();
    return {
      if (productId != null && productId.isNotEmpty) 'product_id': productId,
      'title': form.title,
      'brand': form.brand,
      'category': form.category,
      'mark': form.mark,
      'description': form.description,
      'text': form.text,
      'price': form.price,
      'old_price': form.oldPrice,
      'quantity': form.quantity,
      'image_urls': form.imageUrls,
      'app_is_visible': form.appIsVisible,
    };
  }
}
