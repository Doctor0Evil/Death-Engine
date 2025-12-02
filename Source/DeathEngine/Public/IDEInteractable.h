#pragma once

#include "UObject/Interface.h"
#include "IDEInteractable.generated.h"

/**
 * Interface for interactable actors to implement OnInteract event.
 */
UINTERFACE(BlueprintType)
class DEATHENGINE_API UDEInteractable : public UInterface
{
    GENERATED_BODY()
};

class DEATHENGINE_API IDEInteractable
{
    GENERATED_BODY()

public:
    /** Called on interaction, InstigatorActor is the actor triggering interaction */
    UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category="Interaction")
    void OnInteract(AActor* InstigatorActor);
};
