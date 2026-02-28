enum AnilistFormat { tv, tvShort, movie, special, ova, ona, music }

extension AnilistFormatExtension on AnilistFormat {
  String toGraphql() => switch (this) {
    AnilistFormat.tv => "TV",
    AnilistFormat.tvShort => "TV_SHORT",
    AnilistFormat.movie => "MOVIE",
    AnilistFormat.special => "SPECIAL",
    AnilistFormat.ova => "OVA",
    AnilistFormat.ona => "ONA",
    AnilistFormat.music => "MUSIC",
  };

  static AnilistFormat? fromGraphql(String? value) => switch (value) {
    "TV" => AnilistFormat.tv,
    "TV_SHORT" => AnilistFormat.tvShort,
    "MOVIE" => AnilistFormat.movie,
    "SPECIAL" => AnilistFormat.special,
    "OVA" => AnilistFormat.ova,
    "ONA" => AnilistFormat.ona,
    "MUSIC" => AnilistFormat.music,
    _ => null,
  };
}

enum AnilistSeason { winter, spring, summer, fall }

extension AnilistSeasonExtension on AnilistSeason {
  String toGraphql() => switch (this) {
    AnilistSeason.winter => "WINTER",
    AnilistSeason.spring => "SPRING",
    AnilistSeason.summer => "SUMMER",
    AnilistSeason.fall => "FALL",
  };

  static AnilistSeason? fromGraphql(String? value) => switch (value) {
    "WINTER" => AnilistSeason.winter,
    "SPRING" => AnilistSeason.spring,
    "SUMMER" => AnilistSeason.summer,
    "FALL" => AnilistSeason.fall,
    _ => null,
  };

  static AnilistSeason inferFromDate(DateTime date) => switch (date.month) {
    1 || 2 || 3 => AnilistSeason.winter,
    4 || 5 || 6 => AnilistSeason.spring,
    7 || 8 || 9 => AnilistSeason.summer,
    _ => AnilistSeason.fall,
  };
}

enum AnilistMediaListStatus {
  current,
  planning,
  completed,
  dropped,
  paused,
  repeating,
}

extension AnilistMediaListStatusExtension on AnilistMediaListStatus {
  String toGraphql() => switch (this) {
    AnilistMediaListStatus.current => "CURRENT",
    AnilistMediaListStatus.planning => "PLANNING",
    AnilistMediaListStatus.completed => "COMPLETED",
    AnilistMediaListStatus.dropped => "DROPPED",
    AnilistMediaListStatus.paused => "PAUSED",
    AnilistMediaListStatus.repeating => "REPEATING",
  };

  static AnilistMediaListStatus? fromGraphql(String? value) => switch (value) {
    "CURRENT" => AnilistMediaListStatus.current,
    "PLANNING" => AnilistMediaListStatus.planning,
    "COMPLETED" => AnilistMediaListStatus.completed,
    "DROPPED" => AnilistMediaListStatus.dropped,
    "PAUSED" => AnilistMediaListStatus.paused,
    "REPEATING" => AnilistMediaListStatus.repeating,
    _ => null,
  };
}

enum AnilistRelationType {
  adaptation,
  prequel,
  sequel,
  parent,
  sideStory,
  character,
  summary,
  alternative,
  spinOff,
  other,
  source,
  compilation,
  contains,
}

extension AnilistRelationTypeExtension on AnilistRelationType {
  String toGraphql() => switch (this) {
    AnilistRelationType.adaptation => "ADAPTATION",
    AnilistRelationType.prequel => "PREQUEL",
    AnilistRelationType.sequel => "SEQUEL",
    AnilistRelationType.parent => "PARENT",
    AnilistRelationType.sideStory => "SIDE_STORY",
    AnilistRelationType.character => "CHARACTER",
    AnilistRelationType.summary => "SUMMARY",
    AnilistRelationType.alternative => "ALTERNATIVE",
    AnilistRelationType.spinOff => "SPIN_OFF",
    AnilistRelationType.other => "OTHER",
    AnilistRelationType.source => "SOURCE",
    AnilistRelationType.compilation => "COMPILATION",
    AnilistRelationType.contains => "CONTAINS",
  };

  static AnilistRelationType? fromGraphql(String? value) => switch (value) {
    "ADAPTATION" => AnilistRelationType.adaptation,
    "PREQUEL" => AnilistRelationType.prequel,
    "SEQUEL" => AnilistRelationType.sequel,
    "PARENT" => AnilistRelationType.parent,
    "SIDE_STORY" => AnilistRelationType.sideStory,
    "CHARACTER" => AnilistRelationType.character,
    "SUMMARY" => AnilistRelationType.summary,
    "ALTERNATIVE" => AnilistRelationType.alternative,
    "SPIN_OFF" => AnilistRelationType.spinOff,
    "OTHER" => AnilistRelationType.other,
    "SOURCE" => AnilistRelationType.source,
    "COMPILATION" => AnilistRelationType.compilation,
    "CONTAINS" => AnilistRelationType.contains,
    _ => null,
  };
}

enum AnilistAiringStatus {
  finished,
  releasing,
  notYetReleased,
  cancelled,
  hiatus,
}

extension AnilistAiringStatusExtension on AnilistAiringStatus {
  String toGraphql() => switch (this) {
    AnilistAiringStatus.finished => "FINISHED",
    AnilistAiringStatus.releasing => "RELEASING",
    AnilistAiringStatus.notYetReleased => "NOT_YET_RELEASED",
    AnilistAiringStatus.cancelled => "CANCELLED",
    AnilistAiringStatus.hiatus => "HIATUS",
  };

  static AnilistAiringStatus? fromGraphql(String? value) => switch (value) {
    "FINISHED" => AnilistAiringStatus.finished,
    "RELEASING" => AnilistAiringStatus.releasing,
    "NOT_YET_RELEASED" => AnilistAiringStatus.notYetReleased,
    "CANCELLED" => AnilistAiringStatus.cancelled,
    "HIATUS" => AnilistAiringStatus.hiatus,
    _ => null,
  };
}

enum AnilistGenre {
  action,
  adventure,
  comedy,
  drama,
  ecchi,
  fantasy,
  hentai,
  horror,
  kids,
  mahouShoujo,
  mecha,
  music,
  mystery,
  psychological,
  romance,
  sciFi,
  sliceOfLife,
  sports,
  supernatural,
  thriller,
}

extension AnilistGenreExtension on AnilistGenre {
  String toGraphql() => switch (this) {
    AnilistGenre.action => "Action",
    AnilistGenre.adventure => "Adventure",
    AnilistGenre.comedy => "Comedy",
    AnilistGenre.drama => "Drama",
    AnilistGenre.ecchi => "Ecchi",
    AnilistGenre.fantasy => "Fantasy",
    AnilistGenre.hentai => "Hentai",
    AnilistGenre.horror => "Horror",
    AnilistGenre.kids => "Kids",
    AnilistGenre.mahouShoujo => "Mahou Shoujo",
    AnilistGenre.mecha => "Mecha",
    AnilistGenre.music => "Music",
    AnilistGenre.mystery => "Mystery",
    AnilistGenre.psychological => "Psychological",
    AnilistGenre.romance => "Romance",
    AnilistGenre.sciFi => "Sci-Fi",
    AnilistGenre.sliceOfLife => "Slice of Life",
    AnilistGenre.sports => "Sports",
    AnilistGenre.supernatural => "Supernatural",
    AnilistGenre.thriller => "Thriller",
  };

  static AnilistGenre? fromGraphql(String? value) => switch (value) {
    "Action" => AnilistGenre.action,
    "Adventure" => AnilistGenre.adventure,
    "Comedy" => AnilistGenre.comedy,
    "Drama" => AnilistGenre.drama,
    "Ecchi" => AnilistGenre.ecchi,
    "Fantasy" => AnilistGenre.fantasy,
    "Hentai" => AnilistGenre.hentai,
    "Horror" => AnilistGenre.horror,
    "Kids" => AnilistGenre.kids,
    "Mahou Shoujo" => AnilistGenre.mahouShoujo,
    "Mecha" => AnilistGenre.mecha,
    "Music" => AnilistGenre.music,
    "Mystery" => AnilistGenre.mystery,
    "Psychological" => AnilistGenre.psychological,
    "Romance" => AnilistGenre.romance,
    "Sci-Fi" => AnilistGenre.sciFi,
    "Slice of Life" => AnilistGenre.sliceOfLife,
    "Sports" => AnilistGenre.sports,
    "Supernatural" => AnilistGenre.supernatural,
    "Thriller" => AnilistGenre.thriller,
    _ => null,
  };
}

enum AnilistMediaSort {
  score,
  popularity,
  trending,
  favourites,
  startDate,
  titleRomaji,
  titleEnglish,
}

extension AnilistMediaSortExtension on AnilistMediaSort {
  String toGraphqlAsc() => switch (this) {
    AnilistMediaSort.score => "SCORE",
    AnilistMediaSort.popularity => "POPULARITY",
    AnilistMediaSort.trending => "TRENDING",
    AnilistMediaSort.favourites => "FAVOURITES",
    AnilistMediaSort.startDate => "START_DATE",
    AnilistMediaSort.titleRomaji => "TITLE_ROMAJI",
    AnilistMediaSort.titleEnglish => "TITLE_ENGLISH",
  };

  String toGraphqlDesc() => "${toGraphqlAsc()}_DESC";

  String toLabel() => switch (this) {
    AnilistMediaSort.score => "Score",
    AnilistMediaSort.popularity => "Popularity",
    AnilistMediaSort.trending => "Trending",
    AnilistMediaSort.favourites => "Favourites",
    AnilistMediaSort.startDate => "Start Date",
    AnilistMediaSort.titleRomaji => "Title (Romaji)",
    AnilistMediaSort.titleEnglish => "Title (English)",
  };
}
