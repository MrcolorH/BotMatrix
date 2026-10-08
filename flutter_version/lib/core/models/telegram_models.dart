class TelegramUser {
  final int id;
  final bool isBot;
  final String firstName;
  final String? lastName;
  final String? username;

  TelegramUser({
    required this.id,
    required this.isBot,
    required this.firstName,
    this.lastName,
    this.username,
  });

  factory TelegramUser.fromJson(Map<String, dynamic> json) {
    return TelegramUser(
      id: json['id'] as int,
      isBot: json['is_bot'] as bool? ?? false,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String?,
      username: json['username'] as String?,
    );
  }

  String get displayName => username != null ? '@$username' : firstName;
}

class TelegramChat {
  final int id;
  final String type; // private, group, supergroup, channel
  final String? title;
  final String? username;

  TelegramChat({
    required this.id,
    required this.type,
    this.title,
    this.username,
  });

  factory TelegramChat.fromJson(Map<String, dynamic> json) {
    return TelegramChat(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'private',
      title: json['title'] as String?,
      username: json['username'] as String?,
    );
  }
}

class TelegramMessage {
  final int messageId;
  final TelegramUser? from;
  final TelegramChat chat;
  final int date;
  final String? text;
  final TelegramMessage? replyToMessage;

  TelegramMessage({
    required this.messageId,
    this.from,
    required this.chat,
    required this.date,
    this.text,
    this.replyToMessage,
  });

  factory TelegramMessage.fromJson(Map<String, dynamic> json) {
    return TelegramMessage(
      messageId: json['message_id'] as int,
      from: json['from'] != null ? TelegramUser.fromJson(json['from']) : null,
      chat: TelegramChat.fromJson(json['chat']),
      date: json['date'] as int? ?? 0,
      text: json['text'] as String?,
      replyToMessage: json['reply_to_message'] != null
          ? TelegramMessage.fromJson(json['reply_to_message'])
          : null,
    );
  }
}

class TelegramCallbackQuery {
  final String id;
  final TelegramUser from;
  final TelegramMessage? message;
  final String? data;

  TelegramCallbackQuery({
    required this.id,
    required this.from,
    this.message,
    this.data,
  });

  factory TelegramCallbackQuery.fromJson(Map<String, dynamic> json) {
    return TelegramCallbackQuery(
      id: json['id'] as String,
      from: TelegramUser.fromJson(json['from']),
      message: json['message'] != null
          ? TelegramMessage.fromJson(json['message'])
          : null,
      data: json['data'] as String?,
    );
  }
}

class TelegramUpdate {
  final int updateId;
  final TelegramMessage? message;
  final TelegramCallbackQuery? callbackQuery;

  TelegramUpdate({
    required this.updateId,
    this.message,
    this.callbackQuery,
  });

  factory TelegramUpdate.fromJson(Map<String, dynamic> json) {
    return TelegramUpdate(
      updateId: json['update_id'] as int,
      message: json['message'] != null
          ? TelegramMessage.fromJson(json['message'])
          : null,
      callbackQuery: json['callback_query'] != null
          ? TelegramCallbackQuery.fromJson(json['callback_query'])
          : null,
    );
  }
}
