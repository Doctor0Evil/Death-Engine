#include "Components/UDEFlashlightComponent.h"
#include "GameFramework/Actor.h"
#include "Kismet/KismetMathLibrary.h"

UDEFlashlightComponent::UDEFlashlightComponent()
{
    PrimaryComponentTick.bCanEverTick = false; // Manual ticking preferred

    Battery = 100.f;
    DrainRate = 1.f;
    FlickerThreshold = 10.f;
    bIsOn = false;
    LightRef = nullptr;
}

void UDEFlashlightComponent::BeginPlay()
{
    Super::BeginPlay();

    if (!LightRef)
    {
        LightRef = GetOwner()->FindComponentByClass<USpotLightComponent>();
    }
}

void UDEFlashlightComponent::Toggle()
{
    // Toggle ON/OFF only if Battery > 0
    if (Battery > 0.f)
    {
        bIsOn = !bIsOn;
        if (LightRef)
        {
            LightRef->SetVisibility(bIsOn);
            if (bIsOn)
            {
                LightRef->SetIntensity(5000.f); // Reset intensity on toggle on
            }
        }
    }
}

void UDEFlashlightComponent::TickBattery(float DeltaTime)
{
    if (!bIsOn || Battery <= 0.f)
    {
        return;
    }

    Battery = FMath::Max(0.f, Battery - DrainRate * DeltaTime);

    if (Battery <= FlickerThreshold && LightRef)
    {
        // Flicker intensity randomization
        float FlickerIntensity = FMath::FRandRange(3000.f, 5000.f);
        LightRef->SetIntensity(FlickerIntensity);
    }

    if (Battery <= 0.f)
    {
        Battery = 0.f;
        bIsOn = false;
        if (LightRef)
        {
            LightRef->SetVisibility(false);
        }
    }
}
