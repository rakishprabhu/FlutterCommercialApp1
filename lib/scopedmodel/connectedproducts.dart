import 'package:scoped_model/scoped_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/subjects.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../model/productinfo.dart';
import '../model/userinfo.dart';
import '../model/authmodel.dart';

class ConnectedProductsModel extends Model {
  List<ProductInfo> _products = [];
  String _selproductId;
  UserInfo _authUser;
  bool _isLoading = false;
}

class ProductModel extends ConnectedProductsModel {
  bool _showFavourites = false;

  List<ProductInfo> get allproducts {
    return List.from(_products);
  }

  List<ProductInfo> get displayedProducts {
    if (_showFavourites) {
      return _products.where((ProductInfo info) => info.isFavourite).toList();
    }
    return List.from(_products);
  }

  String get selectedProductId {
    return _selproductId;
  }

  ProductInfo get selectedProduct {
    if (selectedProductId == null) {
      return null;
    }
    return _products.firstWhere((ProductInfo info) {
      return info.id == _selproductId;
    });
  }

  bool get displayFavouritesOnly {
    return _showFavourites;
  }

  int get selectedProductIndex {
    return _products.indexWhere((ProductInfo info) {
      return info.id == _selproductId;
    });
  }

  Future<bool> addGlass(
      String title, String description, String image, double price) async {
    _isLoading = true;
    notifyListeners();
    Map<String, dynamic> newproductt = {
      'title': title,
      'description': description,
      'image':
          'https://s3.ap-south-1.amazonaws.com/zoom-blog-image/2015/10/155670-3.jpg',
      'price': price,
      'email': _authUser.email,
      'userID': _authUser.userid
    };
    try {
      final http.Response response = await http.post(
          'https://fluttertrial.firebaseio.com/product.json?auth=${_authUser.token}',
          body: json.encode(newproductt));
      if (response.statusCode != 200 && response.statusCode != 201) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final Map<String, dynamic> responsedata = json.decode(response.body);
      final newproductinfo = ProductInfo(
          id: responsedata['name'],
          title: title,
          description: description,
          image: image,
          price: price,
          email: _authUser.email,
          userID: _authUser.userid);
      _products.add(newproductinfo);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGlass(
      String title, String description, String image, double price) {
    _isLoading = true;
    notifyListeners();
    final Map<String, dynamic> updatedProduct = {
      'title': title,
      'description': description,
      'image': image,
      'price': price,
      'email': selectedProduct.email,
      'userID': selectedProduct.userID
    };
    return http
        .put(
            'https://fluttertrial.firebaseio.com/product/${selectedProduct.id}.json?auth=${_authUser.token}',
            body: json.encode(updatedProduct))
        .then((http.Response response) {
      final updatedproductinfo = ProductInfo(
          id: selectedProduct.id,
          title: title,
          description: description,
          image: image,
          price: price,
          email: selectedProduct.email,
          userID: selectedProduct.userID);
      _products[selectedProductIndex] = updatedproductinfo;
      _isLoading = false;
      notifyListeners();
      return true;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return false;
    });
  }

  Future<bool> deleteGlass() {
    _isLoading = true;
    final deleteProductID = selectedProduct.id;
    _products.removeAt(selectedProductIndex);
    _selproductId = null;
    notifyListeners();
    return http
        .delete(
            'https://fluttertrial.firebaseio.com/product/$deleteProductID.json?auth=${_authUser.token}')
        .then((http.Response response) {
      _isLoading = false;
      notifyListeners();
      return true;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return false;
    });
  }

  void selectProduct(String productId) {
    _selproductId = productId;
    notifyListeners();
  }

  Future<Null> fetchProducts() {
    _isLoading = true;
    notifyListeners();
    return http
        .get(
            'https://fluttertrial.firebaseio.com/product.json?auth=${_authUser.token}')
        .then<Null>((http.Response response) {
      final Map<String, dynamic> fetchedProducts = json.decode(response.body);
      final List<ProductInfo> fetchedProductList = [];
      if (fetchedProducts == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      fetchedProducts.forEach((String key, dynamic value) {
        final ProductInfo productinfos = ProductInfo(
            title: value['title'],
            description: value['description'],
            image: value['image'],
            price: value['price'],
            id: key,
            email: value['email'],
            userID: value['userID']);
        fetchedProductList.add(productinfos);
      });
      _products = fetchedProductList;
      _isLoading = false;
      notifyListeners();
      _selproductId = null;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return;
    });
  }

  void toggleFavouriteStatus() {
    final currentFavouriteStatus = selectedProduct.isFavourite;
    final updatedFavouriteStatus = !currentFavouriteStatus;

    final ProductInfo updatedproduct = ProductInfo(
        id: selectedProduct.id,
        title: selectedProduct.title,
        description: selectedProduct.description,
        image: selectedProduct.image,
        price: selectedProduct.price,
        email: selectedProduct.email,
        userID: selectedProduct.userID,
        isFavourite: updatedFavouriteStatus);
    _products[selectedProductIndex] = updatedproduct;
    notifyListeners();
  }

  void toggleDisplayMode() {
    _showFavourites = !_showFavourites;
    notifyListeners();
  }
}

class UserModel extends ConnectedProductsModel {
  Timer _authTimer;
  PublishSubject<bool> _userSubject = PublishSubject();

  UserInfo get user {
    return _authUser;
  }

  PublishSubject<bool> get userSubject {
    return _userSubject;
  }

  Future<Map<String, dynamic>> authenticate(String email, String password,
      [AuthMode mode = AuthMode.Login]) async {
    _isLoading = true;
    notifyListeners();
    final Map<String, dynamic> authData = {
      'email': email,
      'password': password,
      'returnSecureToken': true
    };
    http.Response response;
    if (mode == AuthMode.Login) {
      response = await http.post(
        'https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=AIzaSyA62ORhyJdB1rZQ_yIAPayGhjIKyYUHp1s',
        body: json.encode(authData),
        headers: {'Content-Type': 'application/json'},
      );
    } else {
      response = await http.post(
        'https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=AIzaSyA62ORhyJdB1rZQ_yIAPayGhjIKyYUHp1s',
        body: json.encode(authData),
        headers: {'Content-Type': 'application/json'},
      );
    }
    final Map<String, dynamic> responseData = json.decode(response.body);
    bool hasError = true;
    String message = 'Something Went Wrong !';
    if (responseData.containsKey('idToken')) {
      hasError = false;
      message = 'Authendication succeeded!';
      _authUser = UserInfo(
          userid: responseData['localId'],
          email: email,
          token: responseData['idToken']);
      setAuthTimeOut(int.parse(responseData['expiresIn']));
      _userSubject.add(true);
      final DateTime now = DateTime.now();
      final DateTime expiryTime =
          now.add(Duration(seconds: int.parse(responseData['expiresIn'])));
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('token', responseData['idToken']);
      prefs.setString('email', email);
      prefs.setString('userid', responseData['localId']);
      prefs.setString('expiryTime', expiryTime.toIso8601String());
    } else if (responseData['error']['message'] == 'EMAIL_NOT_FOUND') {
      message = 'This email not found !';
    } else if (responseData['error']['message'] == 'INVALID_PASSWORD') {
      message = 'Password in invalid !';
    } else if (responseData['error']['message'] == 'USER_DISABLED') {
      message = 'This User was Disabled !';
    } else if (responseData['error']['message'] == 'EMAIL_EXISTS') {
      message = 'This email already exists !';
    }
    _isLoading = false;
    notifyListeners();
    return {'success': !hasError, 'message': message};
  }

  void autoAuthenticate() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String expiryTimeString = prefs.getString('expiryTime');
    final String token = prefs.getString('token');
    if (token != null) {
      final DateTime now = DateTime.now();
      final parsedexpiryTime = DateTime.parse(expiryTimeString);
      if (parsedexpiryTime.isBefore(now)) {
        _authUser = null;
        notifyListeners();
        return;
      }
      final String userid = prefs.getString('userid');
      final String email = prefs.getString('email');
      final tokenLifeSpan = parsedexpiryTime.difference(now).inSeconds;
      _authUser = UserInfo(userid: userid, email: email, token: token);
      _userSubject.add(true);
      setAuthTimeOut(tokenLifeSpan);
      notifyListeners();
    }
  }

  void logout() async {
    _authUser = null;
    _authTimer.cancel();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('token');
    prefs.remove('email');
    prefs.remove('userid');
  }

  void setAuthTimeOut(int time) {
    _authTimer = Timer(Duration(seconds: time), () {
      logout();
       _userSubject.add(false);
    });
  }
}

class UtilityModel extends ConnectedProductsModel {
  bool get isLoading {
    return _isLoading;
  }
}
