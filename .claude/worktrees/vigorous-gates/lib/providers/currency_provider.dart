import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────
//  Modèle devise
// ─────────────────────────────────────────────────────────────────

class CurrencyMeta {
  final String name;
  final String symbol;
  final String flag;
  const CurrencyMeta({
    required this.name,
    required this.symbol,
    required this.flag,
  });
}

// ─────────────────────────────────────────────────────────────────
//  Toutes les devises mondiales (ISO 4217)
// ─────────────────────────────────────────────────────────────────

const Map<String, CurrencyMeta> kSupportedCurrencies = {
  // ── Maghreb / Moyen-Orient ────────────────────────────────
  'TND': CurrencyMeta(name: 'Dinar Tunisien',       symbol: 'DT',    flag: '🇹🇳'),
  'DZD': CurrencyMeta(name: 'Dinar Algérien',        symbol: 'DA',    flag: '🇩🇿'),
  'MAD': CurrencyMeta(name: 'Dirham Marocain',       symbol: 'MAD',   flag: '🇲🇦'),
  'LYD': CurrencyMeta(name: 'Dinar Libyen',          symbol: 'LD',    flag: '🇱🇾'),
  'EGP': CurrencyMeta(name: 'Livre Égyptienne',      symbol: 'E£',    flag: '🇪🇬'),
  'SAR': CurrencyMeta(name: 'Riyal Saoudien',        symbol: 'ر.س',   flag: '🇸🇦'),
  'AED': CurrencyMeta(name: 'Dirham EAU',            symbol: 'د.إ',   flag: '🇦🇪'),
  'QAR': CurrencyMeta(name: 'Riyal Qatari',          symbol: 'ر.ق',   flag: '🇶🇦'),
  'KWD': CurrencyMeta(name: 'Dinar Koweïtien',       symbol: 'د.ك',   flag: '🇰🇼'),
  'BHD': CurrencyMeta(name: 'Dinar Bahreïni',        symbol: '.د.ب',  flag: '🇧🇭'),
  'OMR': CurrencyMeta(name: 'Rial Omanais',          symbol: 'ر.ع.',  flag: '🇴🇲'),
  'JOD': CurrencyMeta(name: 'Dinar Jordanien',       symbol: 'JD',    flag: '🇯🇴'),
  'LBP': CurrencyMeta(name: 'Livre Libanaise',       symbol: 'ل.ل',   flag: '🇱🇧'),
  'IQD': CurrencyMeta(name: 'Dinar Irakien',         symbol: 'ع.د',   flag: '🇮🇶'),
  'SYP': CurrencyMeta(name: 'Livre Syrienne',        symbol: '£S',    flag: '🇸🇾'),
  'YER': CurrencyMeta(name: 'Rial Yéménite',         symbol: '﷼',     flag: '🇾🇪'),
  'SDG': CurrencyMeta(name: 'Livre Soudanaise',      symbol: 'ج.س',   flag: '🇸🇩'),
  'MRU': CurrencyMeta(name: 'Ouguiya Mauritanien',   symbol: 'UM',    flag: '🇲🇷'),
  'IRR': CurrencyMeta(name: 'Rial Iranien',          symbol: '﷼',     flag: '🇮🇷'),
  'ILS': CurrencyMeta(name: 'Shekel Israélien',      symbol: '₪',     flag: '🇮🇱'),
  // ── Europe ───────────────────────────────────────────────
  'EUR': CurrencyMeta(name: 'Euro',                  symbol: '€',     flag: '🇪🇺'),
  'GBP': CurrencyMeta(name: 'Livre Sterling',        symbol: '£',     flag: '🇬🇧'),
  'CHF': CurrencyMeta(name: 'Franc Suisse',          symbol: 'CHF',   flag: '🇨🇭'),
  'SEK': CurrencyMeta(name: 'Couronne Suédoise',     symbol: 'kr',    flag: '🇸🇪'),
  'NOK': CurrencyMeta(name: 'Couronne Norvégienne',  symbol: 'kr',    flag: '🇳🇴'),
  'DKK': CurrencyMeta(name: 'Couronne Danoise',      symbol: 'kr',    flag: '🇩🇰'),
  'PLN': CurrencyMeta(name: 'Zloty Polonais',        symbol: 'zł',    flag: '🇵🇱'),
  'CZK': CurrencyMeta(name: 'Couronne Tchèque',      symbol: 'Kč',    flag: '🇨🇿'),
  'HUF': CurrencyMeta(name: 'Forint Hongrois',       symbol: 'Ft',    flag: '🇭🇺'),
  'RON': CurrencyMeta(name: 'Leu Roumain',           symbol: 'lei',   flag: '🇷🇴'),
  'BGN': CurrencyMeta(name: 'Lev Bulgare',           symbol: 'лв',    flag: '🇧🇬'),
  'RSD': CurrencyMeta(name: 'Dinar Serbe',           symbol: 'дин',   flag: '🇷🇸'),
  'UAH': CurrencyMeta(name: 'Hryvnia Ukrainien',     symbol: '₴',     flag: '🇺🇦'),
  'TRY': CurrencyMeta(name: 'Lire Turque',           symbol: '₺',     flag: '🇹🇷'),
  'RUB': CurrencyMeta(name: 'Rouble Russe',          symbol: '₽',     flag: '🇷🇺'),
  'ISK': CurrencyMeta(name: 'Couronne Islandaise',   symbol: 'kr',    flag: '🇮🇸'),
  'GEL': CurrencyMeta(name: 'Lari Géorgien',         symbol: '₾',     flag: '🇬🇪'),
  'AMD': CurrencyMeta(name: 'Dram Arménien',         symbol: '֏',     flag: '🇦🇲'),
  'AZN': CurrencyMeta(name: 'Manat Azéri',           symbol: '₼',     flag: '🇦🇿'),
  'KZT': CurrencyMeta(name: 'Tenge Kazakh',          symbol: '₸',     flag: '🇰🇿'),
  'UZS': CurrencyMeta(name: 'Sum Ouzbek',            symbol: "soʻm",  flag: '🇺🇿'),
  'MDL': CurrencyMeta(name: 'Leu Moldave',           symbol: 'L',     flag: '🇲🇩'),
  'ALL': CurrencyMeta(name: 'Lek Albanais',          symbol: 'L',     flag: '🇦🇱'),
  'MKD': CurrencyMeta(name: 'Denar Macédonien',      symbol: 'ден',   flag: '🇲🇰'),
  'BAM': CurrencyMeta(name: 'Mark Bosnien',          symbol: 'KM',    flag: '🇧🇦'),
  // ── Amériques ────────────────────────────────────────────
  'USD': CurrencyMeta(name: 'Dollar US',             symbol: '\$',    flag: '🇺🇸'),
  'CAD': CurrencyMeta(name: 'Dollar Canadien',       symbol: 'CA\$',  flag: '🇨🇦'),
  'MXN': CurrencyMeta(name: 'Peso Mexicain',         symbol: 'Mex\$', flag: '🇲🇽'),
  'BRL': CurrencyMeta(name: 'Real Brésilien',        symbol: 'R\$',   flag: '🇧🇷'),
  'ARS': CurrencyMeta(name: 'Peso Argentin',         symbol: 'AR\$',  flag: '🇦🇷'),
  'CLP': CurrencyMeta(name: 'Peso Chilien',          symbol: 'CL\$',  flag: '🇨🇱'),
  'COP': CurrencyMeta(name: 'Peso Colombien',        symbol: 'CO\$',  flag: '🇨🇴'),
  'PEN': CurrencyMeta(name: 'Sol Péruvien',          symbol: 'S/.',   flag: '🇵🇪'),
  'UYU': CurrencyMeta(name: 'Peso Uruguayen',        symbol: '\$U',   flag: '🇺🇾'),
  'BOB': CurrencyMeta(name: 'Boliviano',             symbol: 'Bs.',   flag: '🇧🇴'),
  'DOP': CurrencyMeta(name: 'Peso Dominicain',       symbol: 'RD\$',  flag: '🇩🇴'),
  'GTQ': CurrencyMeta(name: 'Quetzal Guatémaltèque', symbol: 'Q',     flag: '🇬🇹'),
  'CRC': CurrencyMeta(name: 'Colón Costa-Ricain',    symbol: '₡',     flag: '🇨🇷'),
  'PAB': CurrencyMeta(name: 'Balboa Panaméen',       symbol: 'B/.',   flag: '🇵🇦'),
  'HNL': CurrencyMeta(name: 'Lempira Hondurien',     symbol: 'L',     flag: '🇭🇳'),
  'NIO': CurrencyMeta(name: 'Córdoba Nicaraguayen',  symbol: 'C\$',   flag: '🇳🇮'),
  'JMD': CurrencyMeta(name: 'Dollar Jamaïcain',      symbol: 'J\$',   flag: '🇯🇲'),
  'TTD': CurrencyMeta(name: 'Dollar de Trinité',     symbol: 'TT\$',  flag: '🇹🇹'),
  'PYG': CurrencyMeta(name: 'Guaraní Paraguayen',    symbol: '₲',     flag: '🇵🇾'),
  'HTG': CurrencyMeta(name: 'Gourde Haïtienne',      symbol: 'G',     flag: '🇭🇹'),
  // ── Asie / Pacifique ─────────────────────────────────────
  'JPY': CurrencyMeta(name: 'Yen Japonais',          symbol: '¥',     flag: '🇯🇵'),
  'CNY': CurrencyMeta(name: 'Yuan Chinois',          symbol: 'CN¥',   flag: '🇨🇳'),
  'INR': CurrencyMeta(name: 'Roupie Indienne',       symbol: '₹',     flag: '🇮🇳'),
  'KRW': CurrencyMeta(name: 'Won Sud-Coréen',        symbol: '₩',     flag: '🇰🇷'),
  'AUD': CurrencyMeta(name: 'Dollar Australien',     symbol: 'A\$',   flag: '🇦🇺'),
  'NZD': CurrencyMeta(name: 'Dollar Néo-Zélandais',  symbol: 'NZ\$',  flag: '🇳🇿'),
  'SGD': CurrencyMeta(name: 'Dollar Singapourien',   symbol: 'S\$',   flag: '🇸🇬'),
  'HKD': CurrencyMeta(name: 'Dollar Hong-Kongais',   symbol: 'HK\$',  flag: '🇭🇰'),
  'TWD': CurrencyMeta(name: 'Dollar de Taïwan',      symbol: 'NT\$',  flag: '🇹🇼'),
  'THB': CurrencyMeta(name: 'Baht Thaïlandais',      symbol: '฿',     flag: '🇹🇭'),
  'IDR': CurrencyMeta(name: 'Roupie Indonésienne',   symbol: 'Rp',    flag: '🇮🇩'),
  'MYR': CurrencyMeta(name: 'Ringgit Malaisien',     symbol: 'RM',    flag: '🇲🇾'),
  'PHP': CurrencyMeta(name: 'Peso Philippin',        symbol: '₱',     flag: '🇵🇭'),
  'VND': CurrencyMeta(name: 'Dông Vietnamien',       symbol: '₫',     flag: '🇻🇳'),
  'PKR': CurrencyMeta(name: 'Roupie Pakistanaise',   symbol: '₨',     flag: '🇵🇰'),
  'BDT': CurrencyMeta(name: 'Taka Bangladais',       symbol: '৳',     flag: '🇧🇩'),
  'LKR': CurrencyMeta(name: 'Roupie Sri-Lankaise',   symbol: 'Rs',    flag: '🇱🇰'),
  'NPR': CurrencyMeta(name: 'Roupie Népalaise',      symbol: 'Rs',    flag: '🇳🇵'),
  'MMK': CurrencyMeta(name: 'Kyat Birman',           symbol: 'K',     flag: '🇲🇲'),
  'KHR': CurrencyMeta(name: 'Riel Cambodgien',       symbol: '៛',     flag: '🇰🇭'),
  'MNT': CurrencyMeta(name: 'Tugrik Mongol',         symbol: '₮',     flag: '🇲🇳'),
  'AFN': CurrencyMeta(name: 'Afghani',               symbol: '؋',     flag: '🇦🇫'),
  // ── Afrique ──────────────────────────────────────────────
  'NGN': CurrencyMeta(name: 'Naira Nigérian',        symbol: '₦',     flag: '🇳🇬'),
  'ZAR': CurrencyMeta(name: 'Rand Sud-Africain',     symbol: 'R',     flag: '🇿🇦'),
  'KES': CurrencyMeta(name: 'Shilling Kényan',       symbol: 'KSh',   flag: '🇰🇪'),
  'GHS': CurrencyMeta(name: 'Cedi Ghanéen',          symbol: 'GH₵',   flag: '🇬🇭'),
  'ETB': CurrencyMeta(name: 'Birr Éthiopien',        symbol: 'Br',    flag: '🇪🇹'),
  'TZS': CurrencyMeta(name: 'Shilling Tanzanien',    symbol: 'TSh',   flag: '🇹🇿'),
  'UGX': CurrencyMeta(name: 'Shilling Ougandais',    symbol: 'USh',   flag: '🇺🇬'),
  'XOF': CurrencyMeta(name: 'Franc CFA Ouest',       symbol: 'CFA',   flag: '🌍'),
  'XAF': CurrencyMeta(name: 'Franc CFA Centre',      symbol: 'FCFA',  flag: '🌍'),
  'ZMW': CurrencyMeta(name: 'Kwacha Zambien',        symbol: 'ZK',    flag: '🇿🇲'),
  'BWP': CurrencyMeta(name: 'Pula Botswanais',       symbol: 'P',     flag: '🇧🇼'),
  'MZN': CurrencyMeta(name: 'Metical Mozambicain',   symbol: 'MT',    flag: '🇲🇿'),
  'MGA': CurrencyMeta(name: 'Ariary Malgache',       symbol: 'Ar',    flag: '🇲🇬'),
  'RWF': CurrencyMeta(name: 'Franc Rwandais',        symbol: 'RF',    flag: '🇷🇼'),
  'AOA': CurrencyMeta(name: 'Kwanza Angolais',       symbol: 'Kz',    flag: '🇦🇴'),
  'CDF': CurrencyMeta(name: 'Franc Congolais',       symbol: 'FC',    flag: '🇨🇩'),
  'SOS': CurrencyMeta(name: 'Shilling Somalien',     symbol: 'Sh',    flag: '🇸🇴'),
  'GMD': CurrencyMeta(name: 'Dalasi Gambien',        symbol: 'D',     flag: '🇬🇲'),
  'GNF': CurrencyMeta(name: 'Franc Guinéen',         symbol: 'FG',    flag: '🇬🇳'),
  'SLL': CurrencyMeta(name: 'Leone Sierra-Léonais',  symbol: 'Le',    flag: '🇸🇱'),
  'LRD': CurrencyMeta(name: 'Dollar Libérien',       symbol: 'L\$',   flag: '🇱🇷'),
  'CVE': CurrencyMeta(name: 'Escudo Cap-Verdien',    symbol: '\$',    flag: '🇨🇻'),
  'ZWL': CurrencyMeta(name: 'Dollar Zimbabwéen',     symbol: 'Z\$',   flag: '🇿🇼'),
  'MWK': CurrencyMeta(name: 'Kwacha du Malawi',      symbol: 'MK',    flag: '🇲🇼'),
  'NAD': CurrencyMeta(name: 'Dollar Namibien',       symbol: 'N\$',   flag: '🇳🇦'),
  'SZL': CurrencyMeta(name: 'Lilangeni du Swaziland',symbol: 'L',     flag: '🇸🇿'),
  'LSL': CurrencyMeta(name: 'Loti du Lesotho',       symbol: 'L',     flag: '🇱🇸'),
  // ── Pacifique / Autres ───────────────────────────────────
  'FJD': CurrencyMeta(name: 'Dollar Fidjien',              symbol: 'FJ\$',  flag: '🇫🇯'),
  'PGK': CurrencyMeta(name: 'Kina Papou',                  symbol: 'K',     flag: '🇵🇬'),
  'XPF': CurrencyMeta(name: 'Franc CFP',                   symbol: '₣',     flag: '🇵🇫'),
  'SBD': CurrencyMeta(name: 'Dollar des Salomon',          symbol: 'SI\$',  flag: '🇸🇧'),
  'VUV': CurrencyMeta(name: 'Vatu du Vanuatu',             symbol: 'VT',    flag: '🇻🇺'),
  'WST': CurrencyMeta(name: 'Tālā Samoan',                 symbol: 'T',     flag: '🇼🇸'),
  'TOP': CurrencyMeta(name: "Paʻanga Tongien",            symbol: 'T\$',  flag: '🇹🇴'),
  'TVD': CurrencyMeta(name: 'Dollar Tuvaluan',             symbol: 'TV\$', flag: '🇹🇻'),
  'KID': CurrencyMeta(name: 'Dollar Kiribatien',           symbol: '\$',   flag: '🇰🇮'),
  // ── Caraïbes / Amériques manquantes ──────────────────────
  'ANG': CurrencyMeta(name: 'Florin Antillais',            symbol: 'ƒ',     flag: '🇨🇼'),
  'AWG': CurrencyMeta(name: 'Florin Arubais',              symbol: 'ƒ',     flag: '🇦🇼'),
  'BBD': CurrencyMeta(name: 'Dollar Barbadien',            symbol: 'Bds\$',flag: '🇧🇧'),
  'BSD': CurrencyMeta(name: 'Dollar Bahamien',             symbol: 'B\$',  flag: '🇧🇸'),
  'BZD': CurrencyMeta(name: 'Dollar du Belize',            symbol: 'BZ\$', flag: '🇧🇿'),
  'CUP': CurrencyMeta(name: 'Peso Cubain',                 symbol: '\$',   flag: '🇨🇺'),
  'GYD': CurrencyMeta(name: 'Dollar Guyanais',             symbol: 'G\$',  flag: '🇬🇾'),
  'KYD': CurrencyMeta(name: 'Dollar des Îles Caïmans',     symbol: 'CI\$', flag: '🇰🇾'),
  'SRD': CurrencyMeta(name: 'Dollar du Suriname',          symbol: 'Sr\$', flag: '🇸🇷'),
  'XCD': CurrencyMeta(name: 'Dollar Caraïbes Orientales',  symbol: 'EC\$', flag: '🇦🇬'),
  'XCG': CurrencyMeta(name: 'Florin Caribéen',             symbol: 'Cg',    flag: '🇸🇽'),
  'VES': CurrencyMeta(name: 'Bolívar Vénézuélien',         symbol: 'Bs.S',  flag: '🇻🇪'),
  // ── Europe manquante ──────────────────────────────────────
  'BYN': CurrencyMeta(name: 'Rouble Biélorusse',           symbol: 'Br',    flag: '🇧🇾'),
  'HRK': CurrencyMeta(name: 'Kuna Croate',                 symbol: 'kn',    flag: '🇭🇷'),
  'GGP': CurrencyMeta(name: 'Livre de Guernesey',          symbol: '£',     flag: '🇬🇬'),
  'IMP': CurrencyMeta(name: "Livre de l'île de Man",     symbol: '£',     flag: '🇮🇲'),
  'JEP': CurrencyMeta(name: 'Livre de Jersey',             symbol: '£',     flag: '🇯🇪'),
  'FKP': CurrencyMeta(name: 'Livre des Malouines',         symbol: '£',     flag: '🇫🇰'),
  'FOK': CurrencyMeta(name: 'Couronne Féroïenne',          symbol: 'kr',    flag: '🇫🇴'),
  'GIP': CurrencyMeta(name: 'Livre de Gibraltar',          symbol: '£',     flag: '🇬🇮'),
  'SHP': CurrencyMeta(name: 'Livre de Sainte-Hélène',      symbol: '£',     flag: '🇸🇭'),
  // ── Asie manquante ────────────────────────────────────────
  'BTN': CurrencyMeta(name: 'Ngultrum Bhoutanais',         symbol: 'Nu',    flag: '🇧🇹'),
  'KGS': CurrencyMeta(name: 'Som Kirghiz',                 symbol: 'с',     flag: '🇰🇬'),
  'LAK': CurrencyMeta(name: 'Kip Laotien',                 symbol: '₭',     flag: '🇱🇦'),
  'MOP': CurrencyMeta(name: 'Pataca de Macao',             symbol: 'P',     flag: '🇲🇴'),
  'MVR': CurrencyMeta(name: 'Rufiyaa Maldivien',           symbol: 'Rf',    flag: '🇲🇻'),
  'TJS': CurrencyMeta(name: 'Somoni Tadjik',               symbol: 'SM',    flag: '🇹🇯'),
  'TMT': CurrencyMeta(name: 'Manat Turkmène',              symbol: 'T',     flag: '🇹🇲'),
  'CNH': CurrencyMeta(name: 'Yuan Offshore Chinois',       symbol: 'CN¥',   flag: '🇨🇳'),
  'CLF': CurrencyMeta(name: 'Unidad de Fomento Chilienne', symbol: 'UF',    flag: '🇨🇱'),
  // ── Afrique manquante ─────────────────────────────────────
  'BIF': CurrencyMeta(name: 'Franc Burundais',             symbol: 'Fr',    flag: '🇧🇮'),
  'DJF': CurrencyMeta(name: 'Franc Djiboutien',            symbol: 'Fr',    flag: '🇩🇯'),
  'ERN': CurrencyMeta(name: 'Nakfa Érythréen',             symbol: 'Nfk',   flag: '🇪🇷'),
  'KMF': CurrencyMeta(name: 'Franc Comorien',              symbol: 'Fr',    flag: '🇰🇲'),
  'MUR': CurrencyMeta(name: 'Roupie Mauricienne',          symbol: 'Rs',    flag: '🇲🇺'),
  'SCR': CurrencyMeta(name: 'Roupie des Seychelles',       symbol: 'Rs',    flag: '🇸🇨'),
  'SLE': CurrencyMeta(name: 'Leone Sierra-Léonais (nouveau)', symbol: 'Le', flag: '🇸🇱'),
  'SSP': CurrencyMeta(name: 'Livre du Soudan du Sud',      symbol: '£',     flag: '🇸🇸'),
  'STN': CurrencyMeta(name: 'Dobra Sao-Toméen',            symbol: 'Db',    flag: '🇸🇹'),
  // ── Divers manquants ──────────────────────────────────────
  'BMD': CurrencyMeta(name: 'Dollar des Bermudes',         symbol: '\$',   flag: '🇧🇲'),
  'BND': CurrencyMeta(name: 'Dollar de Brunei',            symbol: 'B\$',  flag: '🇧🇳'),
  'XDR': CurrencyMeta(name: 'Droits de Tirage Spéciaux',   symbol: 'SDR',   flag: '🌐'),
  'ZWG': CurrencyMeta(name: 'Dollar Zimbabwéen (ZiG)',      symbol: 'ZiG',   flag: '🇿🇼'),
};

// ─────────────────────────────────────────────────────────────────
//  CurrencyProvider
// ─────────────────────────────────────────────────────────────────

class CurrencyProvider extends ChangeNotifier {
  String              _selectedCode = 'USD';
  Map<String, double> _rates        = {'USD': 1.0};
  bool                _isLoading    = false;
  String              _lastUpdated  = '';
  String              _error        = '';

  // ── Clés SharedPreferences ───────────────────────────────────
  // Les taux sont partagés (une seule requête API pour tous)
  // La devise choisie est par UID → clé "selected_currency_<uid>"
  static const _kRatesKey     = 'cached_rates_v2';   // ✅ v2 = base USD (v1 était TND)
  static const _kRatesDate    = 'cached_rates_date_v2';

  // Clé devise personnalisée par utilisateur
  static String _currencyKey(String uid) => 'selected_currency_$uid';

  // UID courant (injecté via init)
  String _uid = '';

  // ── Getters ──────────────────────────────────────────────────

  String get selectedCode => _selectedCode;
  bool   get isLoading    => _isLoading;
  String get lastUpdated  => _lastUpdated;
  String get error        => _error;

  CurrencyMeta get selectedMeta =>
      kSupportedCurrencies[_selectedCode] ??
          const CurrencyMeta(name: 'Dollar US', symbol: '\$', flag: '🇺🇸');

  String get selectedSymbol => selectedMeta.symbol;
  String get selectedFlag   => selectedMeta.flag;
  String get selectedName   => selectedMeta.name;

  Map<String, CurrencyMeta> get currencies => kSupportedCurrencies;

  // ── Init ─────────────────────────────────────────────────────
  //
  //  Appelé avec l'UID de l'utilisateur connecté.
  //  Chaque compte a sa propre devise sauvegardée.
  //  Les taux de change (API) sont communs à tous → une seule
  //  requête réseau suffit, peu importe qui est connecté.

  Future<void> init({String uid = ''}) async {
    _uid = uid;
    final prefs = await SharedPreferences.getInstance();

    // ── Devise : lire depuis la clé propre à cet UID ─────────
    if (uid.isNotEmpty) {
      _selectedCode = prefs.getString(_currencyKey(uid)) ?? 'USD';
    } else {
      _selectedCode = 'USD';
    }

    // ── Taux : cache commun (indépendant de l'utilisateur) ───
    final cachedJson = prefs.getString(_kRatesKey);
    final cachedDate = prefs.getString(_kRatesDate) ?? '';
    if (cachedJson != null) {
      try {
        final decoded = json.decode(cachedJson) as Map<String, dynamic>;
        _rates       = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
        _lastUpdated = cachedDate;
      } catch (_) {}
    }
    notifyListeners();
    if (_shouldRefresh(cachedDate)) await fetchRates();
  }

  // ── Changer d'utilisateur connecté ───────────────────────────
  //
  //  Appelé lors d'un changement de compte (connexion / déconnexion).
  //  Recharge la devise de l'utilisateur sans re-fetcher les taux.

  Future<void> switchUser(String uid) async {
    _uid = uid;
    final prefs = await SharedPreferences.getInstance();
    if (uid.isNotEmpty) {
      _selectedCode = prefs.getString(_currencyKey(uid)) ?? 'USD';
    } else {
      _selectedCode = 'USD';
    }
    notifyListeners();
  }

  bool _shouldRefresh(String dateStr) {
    if (dateStr.isEmpty) return true;
    try {
      return DateTime.now().difference(DateTime.parse(dateStr)).inHours >= 6;
    } catch (_) { return true; }
  }

  // ── Changer de devise (sauvegardé par UID) ────────────────────

  Future<void> setCurrency(String code) async {
    if (!kSupportedCurrencies.containsKey(code)) return;
    _selectedCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // Sauvegarder sous la clé propre à cet utilisateur
    if (_uid.isNotEmpty) {
      await prefs.setString(_currencyKey(_uid), code);
    }
  }

  // ── Récupérer les taux réels ──────────────────────────────────
  //
  //  API GRATUITE : https://open.er-api.com/v6/latest/USD
  //  • Pas de clé API requise
  //  • 1500 requêtes / mois gratuites
  //  • Mise à jour quotidienne des taux
  //  • Docs : https://www.exchangerate-api.com/docs/free

  Future<void> fetchRates() async {
    _isLoading = true;
    _error     = '';
    notifyListeners();

    try {
      final uri      = Uri.parse('https://open.er-api.com/v6/latest/USD');
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['result'] == 'success') {
          final ratesRaw = data['rates'] as Map<String, dynamic>;
          final filtered = <String, double>{'USD': 1.0};
          for (final code in kSupportedCurrencies.keys) {
            if (ratesRaw.containsKey(code)) {
              filtered[code] = (ratesRaw[code] as num).toDouble();
            }
          }
          _rates       = filtered;
          _lastUpdated = DateTime.now().toIso8601String();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kRatesKey,
              json.encode(_rates.map((k, v) => MapEntry(k, v))));
          await prefs.setString(_kRatesDate, _lastUpdated);
        } else {
          _error = data['error-type']?.toString() ?? 'unknown';
        }
      } else {
        _error = 'HTTP ${response.statusCode}';
      }
    } on TimeoutException {
      _error = 'timeout';
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Conversions ───────────────────────────────────────────────

  /// Prix USD → devise sélectionnée
  double convert(double usdPrice) {
    final rate = _rates[_selectedCode] ?? 1.0;
    return usdPrice * rate;
  }

  /// Prix USD → devise cible spécifique
  double? convertTo(double usdPrice, String targetCode) {
    final rate = _rates[targetCode];
    if (rate == null) return null;
    return usdPrice * rate;
  }

  // ── ✅ Taux croisé dynamique ──────────────────────────────────
  //
  //  On ne compare plus toujours par rapport au TND.
  //  Si l'utilisateur a choisi EUR, on affiche :
  //    "1 EUR = 3.37 TND", "1 EUR = 1.09 USD", etc.
  //
  //  Formule : rate(selected→target) = rates[target] / rates[selected]

  double? crossRate(String targetCode) {
    if (targetCode == _selectedCode) return 1.0;
    final rateSelected = _rates[_selectedCode];
    final rateTarget   = _rates[targetCode];
    if (rateSelected == null || rateSelected == 0 || rateTarget == null) {
      return null;
    }
    return rateTarget / rateSelected;
  }

  /// Formater le taux croisé : "1 EUR = 3.37 TND"
  String formatCrossRate(String targetCode) {
    if (targetCode == _selectedCode) return '= 1.00 $_selectedCode';
    final rate = crossRate(targetCode);
    if (rate == null) return '—';
    // Précision adaptée à la magnitude
    final int precision;
    if (rate >= 1000) precision = 0;
    else if (rate >= 100) precision = 1;
    else if (rate >= 1)   precision = 3;
    else                  precision = 5;
    return '1 $_selectedCode = ${rate.toStringAsFixed(precision)} $targetCode';
  }

  // ── Formatage prix ────────────────────────────────────────────

  String formatPrice(double usdPrice) {
    final converted = convert(usdPrice);
    final symbol    = selectedSymbol;
    final formatted = converted.toStringAsFixed(2);
    const prefixSymbols = {
      '\$', '£', '€', '₹', '₩', '¥', '₺', '₽', '₴', '₪', '₾',
      '֏', '₼', '₸', '₮', '₭', '₫', '₱', '฿', '₡', '₦', '₲',
      '₵', '৳', '؋', '﷼', '₨', '㉾',
    };
    return prefixSymbols.contains(symbol)
        ? '$symbol$formatted'
        : '$formatted $symbol';
  }

  String get lastUpdatedFormatted {
    if (_lastUpdated.isEmpty) return '—';
    try {
      final dt = DateTime.parse(_lastUpdated).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/'
          '${dt.month.toString().padLeft(2,'0')}/${dt.year}  '
          '${dt.hour.toString().padLeft(2,'0')}:'
          '${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return '—'; }
  }
}