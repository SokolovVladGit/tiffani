sealed class StoresDeliveryEvent {
  const StoresDeliveryEvent();
}

final class StoresDeliveryStarted extends StoresDeliveryEvent {
  const StoresDeliveryStarted();
}

final class StoresDeliveryRefreshed extends StoresDeliveryEvent {
  const StoresDeliveryRefreshed();
}
