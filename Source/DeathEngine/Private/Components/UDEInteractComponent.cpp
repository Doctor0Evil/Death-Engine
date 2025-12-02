#include "Components/UDEInteractComponent.h"
#include "GameFramework/Actor.h"
#include "Engine/World.h"
#include "DrawDebugHelpers.h"
#include "IDEInteractable.h"

UDEInteractComponent::UDEInteractComponent()
{
    PrimaryComponentTick.bCanEverTick = false; // Manual tick preferred
    InteractionRange = 250.f;
    CurrentFocusedActor = nullptr;
}

void UDEInteractComponent::BeginPlay()
{
    Super::BeginPlay();
}

void UDEInteractComponent::UpdateFocus()
{
    AActor* Owner = GetOwner();
    if (!Owner) return;

    FVector Start;
    FRotator ViewRotation;
    Owner->GetActorEyesViewPoint(Start, ViewRotation);
    FVector End = Start + (ViewRotation.Vector() * InteractionRange);

    FHitResult HitResult;
    FCollisionQueryParams Params;
    Params.AddIgnoredActor(Owner);

    const bool bHit = GetWorld()->LineTraceSingleByChannel(HitResult, Start, End, ECC_Visibility, Params);

#if !UE_BUILD_SHIPPING
    DrawDebugLine(GetWorld(), Start, End, FColor::Green, false, 0.1f, 0, 1.f);
#endif

    AActor* NewFocusedActor = nullptr;
    if (bHit && HitResult.GetActor() && HitResult.GetActor()->GetClass()->ImplementsInterface(UDEInteractable::StaticClass()))
    {
        NewFocusedActor = HitResult.GetActor();
    }

    if (CurrentFocusedActor != NewFocusedActor)
    {
        CurrentFocusedActor = NewFocusedActor;
        OnFocusedActorChanged.Broadcast(CurrentFocusedActor);
    }
}

void UDEInteractComponent::Interact()
{
    if (CurrentFocusedActor && CurrentFocusedActor->GetClass()->ImplementsInterface(UDEInteractable::StaticClass()))
    {
        IDEInteractable::Execute_OnInteract(CurrentFocusedActor, GetOwner());
    }
}
