class PlayingCard {
  String suit;
  String value;
  int multiplier;
  int score;
  int endSelfScore;
  int givesCards;
  int cardGivingDirection;

  PlayingCard(
      {this.suit,
      this.value,
      this.multiplier,
      this.score,
      this.endSelfScore,
      this.givesCards,
      this.cardGivingDirection});

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
        suit: json['suit'],
        value: json['value'],
        multiplier: json['multiplier'],
        score: json['score'],
        endSelfScore: json['endSelfScore'],
        givesCards: json['givesCards'],
        cardGivingDirection: json['cardGivingDirection']);
  }

  String get string {
    return '${suit}_${value}';
  }
}
