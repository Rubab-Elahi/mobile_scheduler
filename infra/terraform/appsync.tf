# ═══════════════════════════════════════════════════════════════════
#  AWS AppSync — GraphQL API for Real-time Task Updates
#  Uses DynamoDB as the data source for CRUD + subscriptions
# ═══════════════════════════════════════════════════════════════════

# ── AppSync IAM Role ─────────────────────────────────────────────
resource "aws_iam_role" "appsync_dynamodb" {
  name = "${local.name_prefix}-appsync-dynamodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "appsync.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "appsync_dynamodb" {
  name = "${local.name_prefix}-appsync-dynamodb-policy"
  role = aws_iam_role.appsync_dynamodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.tasks.arn,
          "${aws_dynamodb_table.tasks.arn}/index/*"
        ]
      }
    ]
  })
}

# ── AppSync GraphQL API ───────────────────────────────────────────
resource "aws_appsync_graphql_api" "main" {
  name                = "${local.name_prefix}-graphql"
  authentication_type = "AMAZON_COGNITO_USER_POOLS"

  user_pool_config {
    user_pool_id   = aws_cognito_user_pool.main.id
    aws_region     = var.aws_region
    default_action = "ALLOW"
  }

  # Enable real-time subscriptions
  additional_authentication_provider {
    authentication_type = "AWS_IAM"
  }

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logging.arn
    field_log_level          = "ERROR"
  }

  tags = {
    Name = "${local.name_prefix}-graphql"
  }
}

# ── AppSync Logging Role ──────────────────────────────────────────
resource "aws_iam_role" "appsync_logging" {
  name = "${local.name_prefix}-appsync-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "appsync.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "appsync_logging" {
  role       = aws_iam_role.appsync_logging.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppSyncPushToCloudWatchLogs"
}

# ── GraphQL Schema ────────────────────────────────────────────────
resource "aws_appsync_graphql_api" "schema" {}  # placeholder reference below

resource "aws_appsync_schema" "main" {
  api_id     = aws_appsync_graphql_api.main.id
  definition = <<-GRAPHQL
    type Task {
      userId:    String!
      taskId:    String!
      title:     String!
      priority:  String
      status:    String
      dueDate:   String
      notes:     String
      createdAt: String
      updatedAt: String
    }

    type Schedule {
      userId:    String!
      date:      String!
      slots:     [ScheduleSlot]
      generatedAt: String
    }

    type ScheduleSlot {
      startTime: String
      endTime:   String
      taskId:    String
      taskTitle: String
      notes:     String
    }

    type Query {
      getTask(userId: String!, taskId: String!): Task
      listTasks(userId: String!, status: String): [Task]
    }

    type Mutation {
      createTask(input: CreateTaskInput!): Task
      updateTask(userId: String!, taskId: String!, input: UpdateTaskInput!): Task
      deleteTask(userId: String!, taskId: String!): Task
    }

    type Subscription {
      onTaskCreated(userId: String!): Task
        @aws_subscribe(mutations: ["createTask"])
      onTaskUpdated(userId: String!): Task
        @aws_subscribe(mutations: ["updateTask"])
    }

    input CreateTaskInput {
      title:    String!
      priority: String
      dueDate:  String
      notes:    String
    }

    input UpdateTaskInput {
      title:    String
      priority: String
      status:   String
      dueDate:  String
      notes:    String
    }

    schema {
      query:        Query
      mutation:     Mutation
      subscription: Subscription
    }
  GRAPHQL
}

# ── DynamoDB Data Source ──────────────────────────────────────────
resource "aws_appsync_datasource" "tasks" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "TasksDynamoDB"
  type             = "AMAZON_DYNAMODB"
  service_role_arn = aws_iam_role.appsync_dynamodb.arn

  dynamodb_config {
    table_name = aws_dynamodb_table.tasks.name
    region     = var.aws_region
  }
}

# ── Resolvers ─────────────────────────────────────────────────────
resource "aws_appsync_resolver" "get_task" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Query"
  field       = "getTask"
  data_source = aws_appsync_datasource.tasks.name

  request_template = <<-VTL
    {
      "version": "2017-02-28",
      "operation": "GetItem",
      "key": {
        "userId":  $util.dynamodb.toDynamoDBJson($ctx.args.userId),
        "taskId":  $util.dynamodb.toDynamoDBJson($ctx.args.taskId)
      }
    }
  VTL

  response_template = "$util.toJson($ctx.result)"
}

resource "aws_appsync_resolver" "list_tasks" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Query"
  field       = "listTasks"
  data_source = aws_appsync_datasource.tasks.name

  request_template = <<-VTL
    {
      "version": "2017-02-28",
      "operation": "Query",
      "index": "UserStatusIndex",
      "query": {
        "expression": "userId = :userId",
        "expressionValues": {
          ":userId": $util.dynamodb.toDynamoDBJson($ctx.args.userId)
        }
      }
    }
  VTL

  response_template = "$util.toJson($ctx.result.items)"
}

resource "aws_appsync_resolver" "create_task" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Mutation"
  field       = "createTask"
  data_source = aws_appsync_datasource.tasks.name

  request_template = <<-VTL
    #set($now = $util.time.nowISO8601())
    #set($taskId = $util.autoId())
    {
      "version": "2017-02-28",
      "operation": "PutItem",
      "key": {
        "userId": $util.dynamodb.toDynamoDBJson($ctx.identity.sub),
        "taskId": $util.dynamodb.toDynamoDBJson($taskId)
      },
      "attributeValues": {
        "title":     $util.dynamodb.toDynamoDBJson($ctx.args.input.title),
        "priority":  $util.dynamodb.toDynamoDBJson($util.defaultIfNull($ctx.args.input.priority, "medium")),
        "status":    $util.dynamodb.toDynamoDBJson("pending"),
        "dueDate":   $util.dynamodb.toDynamoDBJson($util.defaultIfNull($ctx.args.input.dueDate, "")),
        "notes":     $util.dynamodb.toDynamoDBJson($util.defaultIfNull($ctx.args.input.notes, "")),
        "createdAt": $util.dynamodb.toDynamoDBJson($now),
        "updatedAt": $util.dynamodb.toDynamoDBJson($now)
      }
    }
  VTL

  response_template = "$util.toJson($ctx.result)"
}
