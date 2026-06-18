enum WeightUnit {
  kilogram(code: 'kg', label: 'Kg.'),
  pound(code: 'lb', label: 'Lb.'),
  gram(code: 'g', label: 'g.'),
  milligram(code: 'mg', label: 'mg.'),
  ounce(code: 'oz', label: 'Oz.'),
  tonne(code: 't', label: 'T.'),
  quintal(code: 'qq', label: 'Qq.'),
  arroba(code: '@', label: '@');

  const WeightUnit({required this.code, required this.label});

  final String code;
  final String label;

  static WeightUnit? fromCode(String? code) {
    for (final unit in values) {
      if (unit.code == code) {
        return unit;
      }
    }
    return null;
  }
}
