import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_place_picker_mb/google_maps_place_picker.dart';
import 'package:google_maps_place_picker_mb/providers/place_provider.dart';
import 'package:google_maps_place_picker_mb/src/components/animated_pin.dart';
import 'package:google_maps_place_picker_mb/src/components/sliding_card.dart';
import 'package:google_maps_webservice/geocoding.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

typedef SelectedPlaceWidgetBuilder = Widget Function(
  BuildContext context,
  PickResult? selectedPlace,
  SearchingState state,
  bool isSearchBarFocused,
);

typedef PinBuilder = Widget Function(
  BuildContext context,
  PinState state,
);

typedef ProvidersBuilder = Future<List<Widget>> Function(LatLng);

class GoogleMapPlacePicker extends StatefulWidget {
  const GoogleMapPlacePicker({
    Key? key,
    required this.initialTarget,
    required this.appBarKey,
    this.selectedPlaceWidgetBuilder,
    this.pinBuilder,
    this.providerBuilder,
    this.onSearchFailed,
    this.onMoveStart,
    this.onMapCreated,
    this.debounceMilliseconds,
    this.enableMapTypeButton,
    this.enableMyLocationButton,
    this.onToggleMapType,
    this.onMyLocation,
    this.onPlacePicked,
    this.usePinPointingSearch,
    this.usePlaceDetailSearch,
    this.selectInitialPosition,
    this.language,
    this.pickArea,
    this.forceSearchOnZoomChanged,
    this.hidePlaceDetailsWhenDraggingPin,
    this.onCameraMoveStarted,
    this.onCameraMove,
    this.onCameraIdle,
    this.selectText,
    this.outsideOfPickAreaText,
    this.zoomGesturesEnabled = true,
    this.zoomControlsEnabled = false,
    this.fullMotion = false,
    this.useProvider = false,
  }) : super(key: key);

  /// GoogleMap pass-through events:
  final Function(PlaceProvider)? onCameraMoveStarted;

  final Function(PlaceProvider)? onCameraIdle;
  final GlobalKey appBarKey;
  final int? debounceMilliseconds;
  final bool? enableMapTypeButton;
  final bool? enableMyLocationButton;
  final bool? forceSearchOnZoomChanged;

  /// Use never scrollable scroll-view with maximum dimensions to prevent unnecessary re-rendering.
  final bool fullMotion;

  final bool? hidePlaceDetailsWhenDraggingPin;
  final LatLng initialTarget;
  final String? language;
  final CameraPositionCallback? onCameraMove;
  final MapCreatedCallback? onMapCreated;
  final VoidCallback? onMoveStart;
  final VoidCallback? onMyLocation;
  final ValueChanged<PickResult>? onPlacePicked;
  final ValueChanged<String>? onSearchFailed;
  final VoidCallback? onToggleMapType;
  final String? outsideOfPickAreaText;
  final CircleArea? pickArea;
  final PinBuilder? pinBuilder;
  final ProvidersBuilder? providerBuilder;
  final bool? selectInitialPosition;
  // strings
  final String? selectText;

  final SelectedPlaceWidgetBuilder? selectedPlaceWidgetBuilder;
  final bool? usePinPointingSearch;
  final bool? usePlaceDetailSearch;
  final bool useProvider;
  final bool zoomControlsEnabled;

  /// Zoom feature toggle
  final bool zoomGesturesEnabled;

  @override
  State<GoogleMapPlacePicker> createState() => _GoogleMapPlacePicker();
}

class _GoogleMapPlacePicker extends State<GoogleMapPlacePicker> {
  Set<Circle>? circles;
  var gMapKey = GlobalKey<_GoogleMapPlacePicker>();

  String _sliderLabelValue = "0";
  double _sliderValue = 0;

  _setCircles(CircleArea area) {
    setState(() {
      // circles = Set.from([
      //   Circle(
      //       circleId: CircleId("myCircle"),
      //       radius: 500,
      //       center: PlaceProvider.of(gMapKey.currentContext!, listen: false)
      //           .cameraPosition!
      //           .target,
      //       fillColor: Color.fromRGBO(171, 39, 133, 0.1),
      //       strokeColor: Color.fromRGBO(171, 39, 133, 0.5),
      //       onTap: () {
      //         print('circle pressed');
      //       })
      // ]);

      circles = Set<Circle>.from([area]);
    });
  }

  // @override
  // initState() {

  //   super.initState();
  // }

  _searchByCameraLocation(PlaceProvider provider) async {
    // We don't want to search location again if camera location is changed by zooming in/out.
    if (widget.forceSearchOnZoomChanged == false &&
        provider.prevCameraPosition != null &&
        provider.prevCameraPosition!.target.latitude ==
            provider.cameraPosition!.target.latitude &&
        provider.prevCameraPosition!.target.longitude ==
            provider.cameraPosition!.target.longitude) {
      provider.placeSearchingState = SearchingState.Idle;
      return;
    }

    provider.placeSearchingState = SearchingState.Searching;

    final GeocodingResponse response =
        await provider.geocoding.searchByLocation(
      Location(
          lat: provider.cameraPosition!.target.latitude,
          lng: provider.cameraPosition!.target.longitude),
      language: widget.language,
    );

    if (response.errorMessage?.isNotEmpty == true ||
        response.status == "REQUEST_DENIED") {
      print("Camera Location Search Error: " + response.errorMessage!);
      if (widget.onSearchFailed != null) {
        widget.onSearchFailed!(response.status);
      }
      provider.placeSearchingState = SearchingState.Idle;
      return;
    }

    if (widget.usePlaceDetailSearch!) {
      final PlacesDetailsResponse detailResponse =
          await provider.places.getDetailsByPlaceId(
        response.results[0].placeId,
        language: widget.language,
      );

      if (detailResponse.errorMessage?.isNotEmpty == true ||
          detailResponse.status == "REQUEST_DENIED") {
        print("Fetching details by placeId Error: " +
            detailResponse.errorMessage!);
        if (widget.onSearchFailed != null) {
          widget.onSearchFailed!(detailResponse.status);
        }
        provider.placeSearchingState = SearchingState.Idle;
        return;
      }

      provider.selectedPlace =
          PickResult.fromPlaceDetailResult(detailResponse.result);
    } else {
      provider.selectedPlace =
          PickResult.fromGeocodingResult(response.results[0]);
    }

    provider.placeSearchingState = SearchingState.Idle;
  }

  // _showBottomSheet() {
  //   var provider = PlaceProvider.of(context, listen: false);

  //   if (provider.pinState == PinState.Idle) {
  //     var widgets = this.widget.useProvider ? _call() : SizedBox.shrink();

  //     showModalBottomSheet(
  //       context: context,
  //       enableDrag: true,
  //       builder: (BuildContext bc) {
  //         return Column(
  //           children: [],
  //         );
  //       },
  //     );
  //   }
  // }

  _adjustCircleRadius(double range) {
    var provider = PlaceProvider.of(gMapKey.currentContext!, listen: false);

    _sliderValue = range;
    _sliderLabelValue = "$range";

    var radius = range * 100;

    provider.Searchradius = radius;

    var circArea =
        CircleArea(center: provider.cameraPosition!.target, radius: radius);

    _setCircles(circArea);
  }

  Widget _buildRangeAdjust() {
    return Positioned.directional(
      textDirection: TextDirection.ltr,
      bottom: 3,
      width: MediaQuery.of(context).size.width,
      child: Container(
        child: Slider(
          value: _sliderValue,
          label: _sliderLabelValue,
          max: 20,
          divisions: 5,
          //TODO add the layer to rebuild provider's listing and add the search radius parameter to callback
          onChanged: (value) => {_adjustCircleRadius(value)},
        ),
      ),
    );
  }

  Widget _buildGoogleMapInner(PlaceProvider? provider, MapType mapType) {
    CameraPosition initialCameraPosition =
        CameraPosition(target: this.widget.initialTarget, zoom: 15);
    return GoogleMap(
      key: gMapKey,
      zoomGesturesEnabled: this.widget.zoomGesturesEnabled,
      zoomControlsEnabled:
          false, // we use our own implementation that supports iOS as well, see _buildZoomButtons()
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      initialCameraPosition: initialCameraPosition,
      mapType: mapType,
      myLocationEnabled: true,
      circles: widget.pickArea != null && widget.pickArea!.radius > 0
          ? Set<Circle>.from([widget.pickArea])
          : circles != null
              ? circles!.toSet()
              : Set<Circle>(),
      onMapCreated: (GoogleMapController controller) {
        if (provider == null) return;
        provider.mapController = controller;
        provider.setCameraPosition(null);
        provider.pinState = PinState.Idle;

        // When select initialPosition set to true.
        if (widget.selectInitialPosition!) {
          provider.setCameraPosition(initialCameraPosition);
          _searchByCameraLocation(provider);
        }

        if (widget.onMapCreated != null) {
          widget.onMapCreated!(controller);
        }
      },
      onCameraIdle: () {
        if (provider == null) return;
        if (provider.isAutoCompleteSearching) {
          provider.isAutoCompleteSearching = false;
          provider.pinState = PinState.Idle;
          provider.placeSearchingState = SearchingState.Idle;
          return;
        }

        // Perform search only if the setting is to true.
        if (widget.usePinPointingSearch!) {
          // Search current camera location only if camera has moved (dragged) before.
          if (provider.pinState == PinState.Dragging) {
            // Cancel previous timer.
            if (provider.debounceTimer?.isActive ?? false) {
              provider.debounceTimer!.cancel();
            }
            provider.debounceTimer =
                Timer(Duration(milliseconds: widget.debounceMilliseconds!), () {
              _searchByCameraLocation(provider);
            });
          }
        }

        provider.pinState = PinState.Idle;

        if (widget.onCameraIdle != null) {
          widget.onCameraIdle!(provider);
        }

        // _buildFloatingCard();
      },
      onCameraMoveStarted: () {
        if (provider == null) return;
        if (widget.onCameraMoveStarted != null) {
          widget.onCameraMoveStarted!(provider);
        }

        provider.setPrevCameraPosition(provider.cameraPosition);

        // Cancel any other timer.
        provider.debounceTimer?.cancel();

        // Update state, dismiss keyboard and clear text.
        provider.pinState = PinState.Dragging;

        // Begins the search state if the hide details is enabled
        if (this.widget.hidePlaceDetailsWhenDraggingPin!) {
          provider.placeSearchingState = SearchingState.Searching;
        }

        widget.onMoveStart!();
      },
      onCameraMove: (CameraPosition position) {
        if (provider == null) return;
        provider.setCameraPosition(position);
        if (widget.onCameraMove != null) {
          widget.onCameraMove!(position);
        }
        var circ = CircleArea(
            center: provider.cameraPosition!.target,
            radius: provider.SearchRadius);
        _setCircles(circ);
      },
      // gestureRecognizers make it possible to navigate the map when it's a
      // child in a scroll view e.g ListView, SingleChildScrollView...
      gestureRecognizers: Set()
        ..add(Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer())),
    );
  }

  Widget _buildGoogleMap(BuildContext context) {
    return Selector<PlaceProvider, MapType>(
        selector: (_, provider) => provider.mapType,
        builder: (_, data, __) => this._buildGoogleMapInner(
            PlaceProvider.of(context, listen: false), data));
  }

  Widget _buildPin() {
    return Center(
      child: Selector<PlaceProvider, PinState>(
        selector: (_, provider) => provider.pinState,
        builder: (context, state, __) {
          if (widget.pinBuilder == null) {
            return _defaultPinBuilder(context, state);
          } else {
            return Builder(
                builder: (builderContext) =>
                    widget.pinBuilder!(builderContext, state));
          }
        },
      ),
    );
  }

  Widget _defaultPinBuilder(BuildContext context, PinState state) {
    if (state == PinState.Preparing) {
      return Container();
    } else if (state == PinState.Idle) {
      return Stack(
        children: <Widget>[
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.place, size: 36, color: Colors.red),
                SizedBox(height: 42),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: <Widget>[
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AnimatedPin(
                    child: Icon(Icons.place, size: 36, color: Colors.red)),
                SizedBox(height: 42),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildFloatingCard() {
    return Selector<PlaceProvider,
        Tuple4<PickResult?, SearchingState, bool, PinState>>(
      selector: (_, provider) => Tuple4(
          provider.selectedPlace,
          provider.placeSearchingState,
          provider.isSearchBarFocused,
          provider.pinState),
      builder: (context, data, __) {
        if ((data.item1 == null && data.item2 == SearchingState.Idle) ||
            data.item3 == true ||
            data.item4 == PinState.Dragging &&
                this.widget.hidePlaceDetailsWhenDraggingPin!) {
          return Container();
        } else {
          if (this.widget.useProvider) {
            return FutureBuilder(
              future: _buildProviderList(context, data.item2, data.item1),
              builder: ((context, snapshot) {
                Widget widg = SizedBox.shrink();
                if (snapshot.hasData) {
                  widg = snapshot.data as Widget;
                }
                return SlidingCard(panel: widg);
              }),
            );
          }

          if (widget.selectedPlaceWidgetBuilder == null) {
            return _defaultPlaceWidgetBuilder(context, data.item1, data.item2);
          } else {
            return Builder(
                builder: (builderContext) => widget.selectedPlaceWidgetBuilder!(
                    builderContext, data.item1, data.item2, data.item3));
          }
        }
      },
    );
  }

  Widget _buildZoomButtons() {
    return Selector<PlaceProvider, Tuple2<GoogleMapController?, LatLng?>>(
      selector: (_, provider) => new Tuple2<GoogleMapController?, LatLng?>(
          provider.mapController, provider.cameraPosition?.target),
      builder: (context, data, __) {
        if (!this.widget.zoomControlsEnabled ||
            data.item1 == null ||
            data.item2 == null) {
          return Container();
        } else {
          return Positioned(
            bottom: 50,
            right: 10,
            child: Card(
              elevation: 4.0,
              child: Container(
                width: 40,
                height: 100,
                child: Column(
                  children: <Widget>[
                    IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () async {
                          double currentZoomLevel =
                              await data.item1!.getZoomLevel();
                          currentZoomLevel = currentZoomLevel + 2;
                          data.item1!.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: data.item2!,
                                zoom: currentZoomLevel,
                              ),
                            ),
                          );
                        }),
                    SizedBox(height: 2),
                    IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () async {
                          double currentZoomLevel =
                              await data.item1!.getZoomLevel();
                          currentZoomLevel = currentZoomLevel - 2;
                          if (currentZoomLevel < 0) currentZoomLevel = 0;
                          data.item1!.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: data.item2!,
                                zoom: currentZoomLevel,
                              ),
                            ),
                          );
                        }),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _defaultPlaceWidgetBuilder(
      BuildContext context, PickResult? data, SearchingState state) {
    return FloatingCard(
      bottomPosition: MediaQuery.of(context).size.height * 0.1,
      leftPosition: MediaQuery.of(context).size.width * 0.15,
      rightPosition: MediaQuery.of(context).size.width * 0.15,
      width: MediaQuery.of(context).size.width * 0.7,
      borderRadius: BorderRadius.circular(12.0),
      elevation: 4.0,
      color: Theme.of(context).cardColor,
      child: state == SearchingState.Searching
          ? _buildLoadingIndicator()
          : _buildSelectionDetails(context, data!),
    );
  }

  Widget _call() {
    return Selector<PlaceProvider,
            Tuple4<PickResult?, SearchingState, bool, PinState>>(
        selector: (_, provider) => Tuple4(
            provider.selectedPlace,
            provider.placeSearchingState,
            provider.isSearchBarFocused,
            provider.pinState),
        builder: (context, data, __) {
          if (data.item4 != PinState.Idle) {}
          return _buildLoadingIndicator();
        });
  }

  Future<Widget> _buildProviderList(
      BuildContext context, SearchingState state, PickResult? pResult) async {
    List<Widget> items = [];

    if (state != SearchingState.Searching) {
      items = await widget.providerBuilder!(
        LatLng(
          pResult!.geometry!.location.lat,
          pResult.geometry!.location.lng,
        ),
      );
    }

    return FloatingCard(
      bottomPosition: MediaQuery.of(context).size.height * 0.1,
      leftPosition: MediaQuery.of(context).size.width / 200,
      rightPosition: MediaQuery.of(context).size.width / 200,
      width: MediaQuery.of(context).size.width * 0.7,
      borderRadius: BorderRadius.circular(12.0),
      elevation: 4.0,
      color: Colors.transparent,
      child: state == SearchingState.Searching
          ? _buildLoadingIndicator()
          : SizedBox(
              height: 100,
              width: MediaQuery.of(context).size.width * 0.5,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: ((context, index) => SizedBox(
                    height: 20,
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: Card(child: items[index]))),
              ),
            ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Positioned.fill(
      bottom: 10,
      child: Container(
        height: 48,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionDetails(BuildContext context, PickResult result) {
    bool canBePicked = widget.pickArea == null ||
        widget.pickArea!.radius <= 0 ||
        Geolocator.distanceBetween(
                widget.pickArea!.center.latitude,
                widget.pickArea!.center.longitude,
                result.geometry!.location.lat,
                result.geometry!.location.lng) <=
            widget.pickArea!.radius;
    MaterialStateColor buttonColor = MaterialStateColor.resolveWith(
        (states) => canBePicked ? Colors.lightGreen : Colors.red);
    return Container(
      margin: EdgeInsets.all(10),
      child: Column(
        children: <Widget>[
          Text(
            result.formattedAddress!,
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          (canBePicked && (widget.selectText?.isEmpty ?? true)) ||
                  (!canBePicked &&
                      (widget.outsideOfPickAreaText?.isEmpty ?? true))
              ? SizedBox.fromSize(
                  size: Size(56, 56), // button width and height
                  child: ClipOval(
                    child: Material(
                      child: InkWell(
                          overlayColor: buttonColor,
                          onTap: () {
                            if (canBePicked) {
                              widget.onPlacePicked!(result);
                            }
                          },
                          child: Icon(
                              canBePicked
                                  ? Icons.check_sharp
                                  : Icons.app_blocking_sharp,
                              color: buttonColor)),
                    ),
                  ),
                )
              : SizedBox.fromSize(
                  size: Size(MediaQuery.of(context).size.width * 0.8,
                      56), // button width and height
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: Material(
                      child: InkWell(
                          overlayColor: buttonColor,
                          onTap: () {
                            if (canBePicked) {
                              widget.onPlacePicked!(result);
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  canBePicked
                                      ? Icons.check_sharp
                                      : Icons.app_blocking_sharp,
                                  color: buttonColor),
                              SizedBox.fromSize(size: new Size(10, 0)),
                              Text(
                                  canBePicked
                                      ? widget.selectText!
                                      : widget.outsideOfPickAreaText!,
                                  style: TextStyle(color: buttonColor))
                            ],
                          )),
                    ),
                  ),
                )
        ],
      ),
    );
  }

  Widget _buildMapIcons(BuildContext context) {
    if (widget.appBarKey.currentContext == null) {
      return Container();
    }
    final RenderBox appBarRenderBox =
        widget.appBarKey.currentContext!.findRenderObject() as RenderBox;
    return Positioned(
      top: appBarRenderBox.size.height,
      right: 15,
      child: Column(
        children: <Widget>[
          widget.enableMapTypeButton!
              ? Container(
                  width: 35,
                  height: 35,
                  child: RawMaterialButton(
                    shape: CircleBorder(),
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black54
                        : Colors.white,
                    elevation: 4.0,
                    onPressed: widget.onToggleMapType,
                    child: Icon(Icons.layers),
                  ),
                )
              : Container(),
          SizedBox(height: 10),
          widget.enableMyLocationButton!
              ? Container(
                  width: 35,
                  height: 35,
                  child: RawMaterialButton(
                    shape: CircleBorder(),
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black54
                        : Colors.white,
                    elevation: 4.0,
                    onPressed: widget.onMyLocation,
                    child: Icon(Icons.my_location),
                  ),
                )
              : Container(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        if (this.widget.fullMotion)
          SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: Stack(
                    alignment: AlignmentDirectional.center,
                    children: [
                      _buildGoogleMap(context),
                      _buildPin(),
                    ],
                  ))),
        if (!this.widget.fullMotion) _buildGoogleMap(context),
        if (!this.widget.fullMotion) _buildPin(),
        _buildMapIcons(context),
        //TODO Checkbox (allow automatching)
        //TODO Look into converting into a bottom sheet.
        //TODO Select a service provider.
        _buildFloatingCard(),

        //TODO Add the slider to adjust search range.
        if (this.widget.useProvider) _buildRangeAdjust(),
        if (!this.widget.useProvider) _buildZoomButtons(),
      ],
    );
  }
}
