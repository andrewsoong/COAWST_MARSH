#include "cppdefs.h"

      MODULE marsh_sed_bedload_mod

#if defined SEDIMENT && defined BEDLOAD && defined MARSH_WAVE_THRUST \
    && defined MARSH_SED_BEDLOAD 
!
!svn $Id: marsh_wave_thrust.F 429 2015-04-20 17:30:26Z arango $
!=======================================================================
!  Copyright (c) 2002-2016 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license           Hernan G. Arango   !
!    See License_ROMS.txt                   Alexander F. Shchepetkin   !
!================================================Neil K. Ganju  =======!
!==============================================Tarandeep S. Kalra======!
!==============================================John C. Warner==========!
!                                                                      ! 
!  References:                                                         !
!                                                                      !
!=======================================================================
!
      implicit none

      PRIVATE
      PUBLIC  :: marsh_sed_bedload

      CONTAINS
!
!***********************************************************************
      SUBROUTINE marsh_sed_bedload (ng, tile)
!***********************************************************************
!
      USE mod_param
      USE mod_forces
      USE mod_grid
      USE mod_ocean
      USE mod_vegetation 
      USE mod_vegarr
      USE mod_sedbed
      USE mod_stepping
      USE marsh_wave_thrust_mod
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng, tile
!
!  Local variable declarations.
!
# include "tile.h"
!
# ifdef PROFILE
      CALL wclock_on (ng, iNLM, 16)
# endif
      CALL marsh_sed_bedload_tile (ng, tile,                            &
     &                       LBi, UBi, LBj, UBj,                        &
     &                       IminS, ImaxS, JminS, JmaxS,                &
     &                       GRID(ng) % om_r,                           &
     &                       GRID(ng) % on_r,                           &
     &                       nstp(ng), nnew(ng),                        &
     &                       VEG(ng) % Thrust_w,                        & 
     &                       VEG(ng) % Thrust_e,                        &
     &                       VEG(ng) % Thrust_n,                        &
     &                       VEG(ng) % Thrust_s,                        &
     &                    SEDBED(ng) % bed_frac,                        &
     &                    SEDBED(ng) % bed,                             &
     &                    SEDBED(ng) % bed_mass,                        &
     &                       VEG(ng)    % marsh_mask)
# ifdef PROFILE
      CALL wclock_off (ng, iNLM, 16)
# endif
      RETURN
      END SUBROUTINE marsh_sed_bedload
!
!***********************************************************************
      SUBROUTINE marsh_sed_bedload_tile (ng, tile,                      &
     &                             LBi, UBi, LBj, UBj,                  &
     &                             IminS, ImaxS, JminS, JmaxS,          &
     &                             om_r, on_r,                          &
     &                             nstp, nnew,                          &
     &                             Thrust_w, Thrust_e,                  &
     &                             Thrust_n, Thrust_s,                  &
     &                             bed_frac, bed, bed_mass,             &
     &                             marsh_mask)
!***********************************************************************
!
      USE mod_param
      USE mod_ncparam
      USE mod_scalars
      USE mod_vegetation 
      USE mod_vegarr
      USE mod_sediment
      USE marsh_wave_thrust_mod
      USE bc_2d_mod, ONLY : bc_r2d_tile
      USE bc_3d_mod, ONLY : bc_r3d_tile

      USE exchange_2d_mod, ONLY : exchange_r2d_tile
# ifdef DISTRIBUTE
      USE mp_exchange_mod, ONLY : mp_exchange2d, mp_exchange3d
      USE mp_exchange_mod, ONLY : mp_exchange4d
# endif
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng, tile
      integer, intent(in) :: LBi, UBi, LBj, UBj
      integer, intent(in) :: IminS, ImaxS, JminS, JmaxS
      integer, intent(in) :: nstp, nnew
!
# ifdef ASSUMED_SHAPE
      real(r8), intent(in) :: Thrust_w(LBi:,LBj:)
      real(r8), intent(in) :: Thrust_e(LBi:,LBj:)
      real(r8), intent(in) :: Thrust_n(LBi:,LBj:)
      real(r8), intent(in) :: Thrust_s(LBi:,LBj:)
      real(r8), intent(in) :: om_r(LBi:,LBj:)
      real(r8), intent(in) :: on_r(LBi:,LBj:)

      real(r8), intent(inout) :: bed(LBi:,LBj:,:,:)
      real(r8), intent(inout) :: bed_frac(LBi:,LBj:,:,:)
      real(r8), intent(inout) :: bed_mass(LBi:,LBj:,:,:,:)

      real(r8), intent(inout) :: marsh_mask(LBi:,LBj:)
# else
      real(r8), intent(in) :: Thrust_w(LBi:UBi,LBj:UBj)
      real(r8), intent(in) :: Thrust_e(LBi:UBi,LBj:UBj)
      real(r8), intent(in) :: Thrust_n(LBi:UBi,LBj:UBj)
      real(r8), intent(in) :: Thrust_s(LBi:UBi,LBj:UBj)
      real(r8), intent(in) :: om_r(LBi:UBi,LBj:UBj)
      real(r8), intent(in) :: on_r(LBi:UBi,LBj:UBj)

      real(r8), intent(inout) :: bed(LBi:UBi,LBj:UBj,Nbed,MBEDP)
      real(r8), intent(inout) :: bed_frac(LBi:UBi,LBj:UBj,Nbed,NST)
      real(r8), intent(inout) :: bed_mass(LBi:UBi,LBj:UBj,Nbed,1:2,NST)

      real(r8), intent(inout) :: marsh_mask(LBi:UBi,LBj:UBj)
# endif
!
!  Local variable declarations.
!
      integer :: i, ised, iveg, j, k
      real(r8) :: cff, cff1, cff2, cff3
!
!-----------------------------------------------------------------------
! Save the initial in a local array bed_ini 
! The change in marsh erosion uses this array
!-----------------------------------------------------------------------
!
      real(r8), dimension(IminS:ImaxS,JminS:JmaxS,NST) :: bed_ini
      real(r8) :: Thrust_crit, crit_bed_mass
      real(r8) :: Eff_thrust 
      real(r8), parameter :: eps = 1.0E-14_r8 ! , dcrit_marsh=0.5_r8 
!
# include "set_bounds.h"
!
!-----------------------------------------------------------------------
! Compute some constant of marsh sediment (May be would be input). 
!-----------------------------------------------------------------------
!     
! Critical thrust or erosion thrust value to be decided 
!
      Thrust_crit=0.0_r8
!
      DO ised=NCS+1,NST
        DO j=Jstr,Jend
          DO i=Istr,Iend
!
!  |           |Thrust North |           |
!--|---------- |-------------|---------  |-------------
!  |Thrust West|   Marsh     |Thrust East| 
!  |-----------|-------------|-----------|
!  |           |Thrust South |           |    
!
! 
! Thrust has units kNewton/m or kg/sec2 
! kfac needs to have the units of kg-m/sec 
! Thrust*kfac has to have units of kg 
!
! A fraction of bed mass moves from this cell to either
! of the four neighboring cells if a critical thrust exceeds 
!
!|------|-----     |   -----     | -----   |-------------
!|      |          |   marsh     |         | 
!|      |  <----   |  <----->    | ---->   |
!|      | add sed  | remove sed  | add sed |   
!|
!
! Thrust from West cell face leads to sediment addition on left cell
!
            cff=on_r(i,j)*dt(ng)
            cff1=bed_mass(i,j,1,nnew,ised)
            Eff_thrust=MAX((ABS(Thrust_w(i,j))-Thrust_crit),0.0_r8)
            cff2=MIN(Eff_thrust*kfac_marsh(ng)*cff*cff1,cff1)
            bed_mass(i-1,j,1,nnew,ised)=bed_mass(i-1,j,1,nnew,ised)+    &
                                        cff2

            IF(Eff_thrust.gt.0.0_r8) THEN
              cff3=1.0_r8
              cff1=MAX(cff1-cff2*cff3,0.0_r8)
            ENDIF
!
! Thrust from East cell face leads to sediment addition on right cell
!
            Eff_thrust=MAX((ABS(Thrust_e(i+1,j))-Thrust_crit),0.0_r8)   
            cff2=MIN(Eff_thrust*kfac_marsh(ng)*cff*cff1,cff1)
            bed_mass(i+1,j,1,nnew,ised)=bed_mass(i+1,j,1,nnew,ised)+    &
                                        cff2

            IF(Eff_thrust.gt.0.0_r8) THEN
              cff3=1.0_r8
              cff1=MAX(cff1-cff2*cff3,0.0_r8)
            ENDIF
!
! Thrust from North cell face leads to sediment addition on cell above
!
            cff=om_r(i,j)*dt(ng)

            Eff_thrust=MAX((ABS(Thrust_n(i,j+1))-Thrust_crit),0.0_r8)
            cff2=MIN(Eff_thrust*kfac_marsh(ng)*cff*cff1,cff1)
            bed_mass(i,j+1,1,nnew,ised)=bed_mass(i,j+1,1,nnew,ised)+    &
                                        cff2

            IF(Eff_thrust.gt.0.0_r8) THEN
              cff3=1.0_r8
              cff1=MAX((cff1-cff2*cff3),0.0_r8)
            ENDIF
!
! Thrust from South cell face leads to sediment addition on cell below
!
            Eff_thrust=MAX((ABS(Thrust_s(i,j))-Thrust_crit),0.0_r8)
            cff2=MIN(Eff_thrust*kfac_marsh(ng)*cff*cff1,cff1)
            bed_mass(i,j-1,1,nnew,ised)=bed_mass(i,j-1,1,nnew,ised)+    &
                                        cff2
            IF(Eff_thrust.gt.0.0_r8) THEN
              cff3=1.0_r8
              cff1=MAX((cff1-cff2*cff3),0.0_r8)
            ENDIF
!
! Save the updated bed mass from the eroded cell
! 
            bed_mass(i,j,1,nnew,ised)=cff1 
!
          END DO
        END DO 
      END DO

!
!-----------------------------------------------------------------------
! Have special flag with SED_MORPH AND MARSH_MORPH THAT MAKE THIS TURN
! ON 
! Compute some constant of marsh sediment (May be would be input). 
!-----------------------------------------------------------------------
!  
      DO j=Jstr,Jend
        DO i=Istr,Iend
!
! Recalculate thickness and fractions for all layers.
!
          DO k=1,Nbed
            cff3=0.0_r8
            DO ised=1,NST
              cff3=cff3+bed_mass(i,j,k,nnew,ised)
            END DO
            IF (cff3.eq.0.0_r8) THEN
              cff3=eps
            END IF
            bed(i,j,k,ithck)=0.0_r8
            DO ised=1,NST
              bed_frac(i,j,k,ised)=bed_mass(i,j,k,nnew,ised)/cff3
              bed(i,j,k,ithck)=MAX(bed(i,j,k,ithck)+                    &
     &                         bed_mass(i,j,k,nnew,ised)/               &
     &                         (Srho(ised,ng)*                          &
     &                          (1.0_r8-bed(i,j,k,iporo))),0.0_r8)
              IF (bed(i,j,k,ithck).le.dcrit_marsh(ng)) THEN 
                marsh_mask(i,j)=0.0_r8
              END IF 
            END DO
            
          END DO
        END DO 
      END DO 
!
!---------------------------------------------------------------------
!  Apply periodic or gradient boundary conditions for output
!  purposes only.
!---------------------------------------------------------------------
!
      CALL bc_r2d_tile (ng, tile,                                       &
     &                  LBi, UBi, LBj, UBj,                             &
     &                  marsh_mask)
      DO ised=1,NST
        CALL bc_r3d_tile (ng, tile,                                     &
     &                    LBi, UBi, LBj, UBj, 1, Nbed,                  &
     &                    bed_frac(:,:,:,ised))
        CALL bc_r3d_tile (ng, tile,                                     &
     &                    LBi, UBi, LBj, UBj, 1, Nbed,                  &
     &                    bed_mass(:,:,:,nnew,ised))
      END DO
# ifdef DISTRIBUTE
        CALL mp_exchange2d (ng, tile, iNLM, 2,                          &
     &                        LBi, UBi, LBj, UBj,                       &
     &                        NghostPoints,                             &
     &                        EWperiodic(ng), NSperiodic(ng),           &
     &                        marsh_mask)
!
      CALL mp_exchange4d (ng, tile, iNLM, 2,                            &
     &                    LBi, UBi, LBj, UBj, 1, Nbed, 1, NST,          &
     &                    NghostPoints,                                 &
     &                    EWperiodic(ng), NSperiodic(ng),               &
     &                    bed_frac,                                     &
     &                    bed_mass(:,:,:,nnew,:))
# endif
      DO i=1,MBEDP
        CALL bc_r3d_tile (ng, tile,                                     &
     &                    LBi, UBi, LBj, UBj, 1, Nbed,                  &
     &                    bed(:,:,:,i))
      END DO
# ifdef DISTRIBUTE
      CALL mp_exchange4d (ng, tile, iNLM, 1,                            &
     &                    LBi, UBi, LBj, UBj, 1, Nbed, 1, MBEDP,        &
     &                    NghostPoints,                                 &
     &                    EWperiodic(ng), NSperiodic(ng),               &
     &                    bed) 
# endif
!
  RETURN
  END SUBROUTINE marsh_sed_bedload_tile
#endif
      END MODULE marsh_sed_bedload_mod
