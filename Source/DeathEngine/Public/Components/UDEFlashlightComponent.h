#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Components/SpotLightComponent.h"
#include "UDEFlashlightComponent.generated.h"

/**
 * Flashlight component with battery mechanics and flicker effect.
 * Designed for attachable use on player or other actors.
 */
UCLASS(ClassGroup=(Custom), meta=(BlueprintSpawnableComponent))
class DEATHENGINE_API UDEFlashlightComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UDEFlashlightComponent();

    /** Current battery charge (0–100) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Flashlight")
    float Battery;

    /** Rate to drain battery per second when on */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Flashlight")
    float DrainRate;

    /** Battery level below which flicker occurs */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Flashlight")
    float FlickerThreshold;

    /** Spotlight component reference (must be set) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Flashlight")
    USpotLightComponent* LightRef;

    /** Is flashlight currently on */
    UPROPERTY(BlueprintReadOnly, Category="Flashlight")
    bool bIsOn;

    /** Toggle flashlight on/off */
    UFUNCTION(BlueprintCallable, Category="Flashlight")
    void Toggle();

    /** Tick battery drain & flicker, call from owning actor/tick */
    UFUNCTION(BlueprintCallable, Category="Flashlight")
    void TickBattery(float DeltaTime);

protected:
    virtual void BeginPlay() override;
};
