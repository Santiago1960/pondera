const recipeServiceUnavailableMessage =
    'Servicio temporalmente no disponible. La receta actual no fue modificada.';

bool isRecipeServiceUnavailableStatus(int statusCode) =>
    statusCode >= 500 && statusCode <= 599;
