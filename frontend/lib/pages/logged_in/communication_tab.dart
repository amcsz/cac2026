import 'package:flutter/material.dart';

import '../../models/organization.dart';
import '../../utils/time_format.dart';

class CommunicationTab extends StatelessWidget {
  const CommunicationTab({
    required this.isAdmin,
    required this.loadingConversations,
    required this.conversationsError,
    required this.conversations,
    required this.selectedConversationId,
    required this.loadingMessages,
    required this.messagesError,
    required this.messages,
    required this.sendingMessage,
    required this.messageController,
    required this.onRefreshConversations,
    required this.onRefreshMessages,
    required this.onSelectConversation,
    required this.onBackToConversations,
    required this.onSendMessage,
    super.key,
  });

  final bool isAdmin;
  final bool loadingConversations;
  final String? conversationsError;
  final List<ReportConversation> conversations;
  final int? selectedConversationId;
  final bool loadingMessages;
  final String? messagesError;
  final List<ReportChatMessage> messages;
  final bool sendingMessage;
  final TextEditingController messageController;
  final VoidCallback onRefreshConversations;
  final ValueChanged<int> onRefreshMessages;
  final ValueChanged<ReportConversation> onSelectConversation;
  final VoidCallback onBackToConversations;
  final VoidCallback onSendMessage;

  @override
  Widget build(BuildContext context) {
    ReportConversation? selectedConversation;
    for (final conversation in conversations) {
      if (conversation.id == selectedConversationId) {
        selectedConversation = conversation;
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        if (wide) {
          return Row(
            children: [
              SizedBox(
                width: 330,
                child: _ConversationList(
                  isAdmin: isAdmin,
                  loadingConversations: loadingConversations,
                  conversationsError: conversationsError,
                  conversations: conversations,
                  selectedConversationId: selectedConversationId,
                  onRefreshConversations: onRefreshConversations,
                  onSelectConversation: onSelectConversation,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _ConversationDetail(
                  isAdmin: isAdmin,
                  conversation: selectedConversation,
                  loadingMessages: loadingMessages,
                  messagesError: messagesError,
                  messages: messages,
                  sendingMessage: sendingMessage,
                  messageController: messageController,
                  onBackToConversations: null,
                  onRefreshMessages: selectedConversation == null
                      ? null
                      : () => onRefreshMessages(selectedConversation!.id),
                  onSendMessage: onSendMessage,
                ),
              ),
            ],
          );
        }

        if (selectedConversation != null) {
          return _ConversationDetail(
            isAdmin: isAdmin,
            conversation: selectedConversation,
            loadingMessages: loadingMessages,
            messagesError: messagesError,
            messages: messages,
            sendingMessage: sendingMessage,
            messageController: messageController,
            onBackToConversations: onBackToConversations,
            onRefreshMessages: () =>
                onRefreshMessages(selectedConversation!.id),
            onSendMessage: onSendMessage,
          );
        }

        return _ConversationList(
          isAdmin: isAdmin,
          loadingConversations: loadingConversations,
          conversationsError: conversationsError,
          conversations: conversations,
          selectedConversationId: selectedConversationId,
          onRefreshConversations: onRefreshConversations,
          onSelectConversation: onSelectConversation,
        );
      },
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.isAdmin,
    required this.loadingConversations,
    required this.conversationsError,
    required this.conversations,
    required this.selectedConversationId,
    required this.onRefreshConversations,
    required this.onSelectConversation,
  });

  final bool isAdmin;
  final bool loadingConversations;
  final String? conversationsError;
  final List<ReportConversation> conversations;
  final int? selectedConversationId;
  final VoidCallback onRefreshConversations;
  final ValueChanged<ReportConversation> onSelectConversation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Communications',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Refresh communications',
                onPressed: loadingConversations ? null : onRefreshConversations,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            isAdmin
                ? 'Report response chats opened by administrators.'
                : 'Responses to your emergency reports.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        Expanded(
          child: _ConversationListBody(
            loadingConversations: loadingConversations,
            conversationsError: conversationsError,
            conversations: conversations,
            selectedConversationId: selectedConversationId,
            onSelectConversation: onSelectConversation,
          ),
        ),
      ],
    );
  }
}

class _ConversationListBody extends StatelessWidget {
  const _ConversationListBody({
    required this.loadingConversations,
    required this.conversationsError,
    required this.conversations,
    required this.selectedConversationId,
    required this.onSelectConversation,
  });

  final bool loadingConversations;
  final String? conversationsError;
  final List<ReportConversation> conversations;
  final int? selectedConversationId;
  final ValueChanged<ReportConversation> onSelectConversation;

  @override
  Widget build(BuildContext context) {
    if (loadingConversations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (conversationsError != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          conversationsError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (conversations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('No report response chats have been opened yet.'),
      );
    }

    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final selected = conversation.id == selectedConversationId;
        return ListTile(
          selected: selected,
          leading: const Icon(Icons.forum_outlined),
          title: Text(conversation.title),
          subtitle: Text(
            conversation.lastMessage.isEmpty
                ? conversation.emergencyTypeLabel
                : conversation.lastMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: conversation.lastMessageAt.isEmpty
              ? null
              : Text(
                  formatTimestamp(conversation.lastMessageAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          onTap: () => onSelectConversation(conversation),
        );
      },
    );
  }
}

class _ConversationDetail extends StatelessWidget {
  const _ConversationDetail({
    required this.isAdmin,
    required this.conversation,
    required this.loadingMessages,
    required this.messagesError,
    required this.messages,
    required this.sendingMessage,
    required this.messageController,
    required this.onBackToConversations,
    required this.onRefreshMessages,
    required this.onSendMessage,
  });

  final bool isAdmin;
  final ReportConversation? conversation;
  final bool loadingMessages;
  final String? messagesError;
  final List<ReportChatMessage> messages;
  final bool sendingMessage;
  final TextEditingController messageController;
  final VoidCallback? onBackToConversations;
  final VoidCallback? onRefreshMessages;
  final VoidCallback onSendMessage;

  @override
  Widget build(BuildContext context) {
    if (conversation == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Select a report response chat.'),
        ),
      );
    }

    return Column(
      children: [
        _ConversationHeader(
          isAdmin: isAdmin,
          conversation: conversation!,
          onBackToConversations: onBackToConversations,
          loadingMessages: loadingMessages,
          onRefreshMessages: onRefreshMessages,
        ),
        const Divider(height: 1),
        Expanded(
          child: _MessagesBody(
            loadingMessages: loadingMessages,
            messagesError: messagesError,
            messages: messages,
          ),
        ),
        _MessageComposer(
          sendingMessage: sendingMessage,
          messageController: messageController,
          onSendMessage: onSendMessage,
        ),
      ],
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.isAdmin,
    required this.conversation,
    required this.onBackToConversations,
    required this.loadingMessages,
    required this.onRefreshMessages,
  });

  final bool isAdmin;
  final ReportConversation conversation;
  final VoidCallback? onBackToConversations;
  final bool loadingMessages;
  final VoidCallback? onRefreshMessages;

  @override
  Widget build(BuildContext context) {
    final reportDetails = conversation.reportDetails.trim();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
        child: Row(
          children: [
            if (onBackToConversations != null)
              IconButton(
                tooltip: 'Back to communications',
                onPressed: onBackToConversations,
                icon: const Icon(Icons.arrow_back),
              ),
            if (onBackToConversations == null) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAdmin
                        ? '${conversation.emergencyTypeLabel} report from ${conversation.reportedByUsername}'
                        : '${conversation.emergencyTypeLabel} report sent ${formatTimestamp(conversation.reportCreatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (reportDetails.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      reportDetails,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh conversation',
              onPressed: loadingMessages ? null : onRefreshMessages,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesBody extends StatelessWidget {
  const _MessagesBody({
    required this.loadingMessages,
    required this.messagesError,
    required this.messages,
  });

  final bool loadingMessages;
  final String? messagesError;
  final List<ReportChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (loadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (messagesError != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          messagesError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No messages yet. Send the first response.'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageBubble(message: message);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ReportChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mine = message.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              mine ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.senderUsername,
              style: TextStyle(
                color: mine ? colorScheme.onPrimary : colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.body,
              style: TextStyle(
                color: mine ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatTimestamp(message.createdAt),
              style: TextStyle(
                color: mine
                    ? colorScheme.onPrimary.withValues(alpha: 0.76)
                    : colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.sendingMessage,
    required this.messageController,
    required this.onSendMessage,
  });

  final bool sendingMessage;
  final TextEditingController messageController;
  final VoidCallback onSendMessage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write a response',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (!sendingMessage) {
                    onSendMessage();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send message',
              onPressed: sendingMessage ? null : onSendMessage,
              icon: sendingMessage
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
