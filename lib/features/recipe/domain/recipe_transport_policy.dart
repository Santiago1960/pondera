const recipeServiceUnavailableMessage =
    'No se pudo contactar al servicio de análisis. Intenta nuevamente. La receta actual no fue modificada.';

bool isRecipeServiceUnavailableStatus(int statusCode) =>
    statusCode >= 500 && statusCode <= 599;
