#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "UDEInteractComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFocusedActorChanged, AActor*, NewFocusedActor);

/**
 * Interaction component performing line-trace to find interactable actors.
 */
UCLASS(ClassGroup=(Custom), meta=(BlueprintSpawnableComponent))
class DEATHENGINE_API UDEInteractComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UDEInteractComponent();

    /** Maximum distance to interact */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Interaction")
    float InteractionRange;

    /** Currently focused/interactable actor */
    UPROPERTY(BlueprintReadOnly, Category="Interaction")
    AActor* CurrentFocusedActor;

    /** Delegate fired when the focused actor changes */
    UPROPERTY(BlueprintAssignable, Category="Interaction")
    FOnFocusedActorChanged OnFocusedActorChanged;

    /** Perform line trace and update focus - call from owning actor tick */
    UFUNCTION(BlueprintCallable, Category="Interaction")
    void UpdateFocus();

    /** Attempt to interact with currently focused actor */
    UFUNCTION(BlueprintCallable, Category="Interaction")
    void Interact();

protected:
    virtual void BeginPlay() override;
};
