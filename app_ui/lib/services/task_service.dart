import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';

class TaskService {
  // ── GraphQL Queries ─────────────────────────────────────────
  static const String listTasksQuery = '''
    query ListTasks(\$userId: String!) {
      listTasks(userId: \$userId) {
        taskId
        title
        priority
        status
        dueDate
      }
    }
  ''';

  // ── Methods ────────────────────────────────────────────────
  Future<void> fetchTasks(String userId) async {
    try {
      final request = GraphQLRequest<String>(
        document: listTasksQuery,
        variables: {'userId': userId},
      );
      final response = await Amplify.API.query(request: request).response;
      
      if (response.data != null) {
        safePrint('Fetched tasks: \${response.data}');
      }
    } on GraphQLResponseError catch (e) {
      safePrint('Errors: \${e.message}');
    }
  }

  Future<void> triggerVoiceAI(String prompt) async {
    try {
      // Calling the REST API (Agentic AI Service)
      final restOptions = RestOptions(
        path: '/ai/chat',
        body: utf8.encode(json.encode({'prompt': prompt})),
      );
      final response = await Amplify.API.post(restOptions: restOptions).response;
      safePrint('AI Response: \${response.decodeBody()}');
    } on Exception catch (e) {
      safePrint('REST Error: \$e');
    }
  }
}
